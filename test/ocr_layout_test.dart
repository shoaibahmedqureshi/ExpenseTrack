import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/receipt_scanner/data/ocr_layout.dart';
import 'package:outlay/features/receipt_scanner/data/receipt_parser.dart';

OcrLine _line(String text, double left, double top,
        {double width = 150, double height = 20}) =>
    OcrLine(
      text: text,
      left: left,
      top: top,
      right: left + width,
      bottom: top + height,
    );

void main() {
  group('reconstructReadingOrder', () {
    test('empty input', () {
      expect(reconstructReadingOrder([]), '');
    });

    test('joins same-row fragments left to right', () {
      final lines = [
        _line('401.00', 300, 100),
        _line('Net Total', 10, 101),
      ];
      expect(reconstructReadingOrder(lines).trim(), 'Net Total 401.00');
    });

    test('keeps separate rows separate', () {
      final lines = [
        _line('Tax', 10, 130),
        _line('Total', 10, 100),
        _line('8.94', 300, 101),
        _line('0.74', 300, 131),
      ];
      expect(
        reconstructReadingOrder(lines).trim().split('\n'),
        ['Total 8.94', 'Tax 0.74'],
      );
    });

    test('tolerates slight skew within half a line height', () {
      // 6px vertical drift across the page on 20px-tall text: same row.
      final lines = [
        _line('9,810', 320, 106),
        _line('Total net amount', 10, 100),
      ];
      expect(
        reconstructReadingOrder(lines).trim(),
        'Total net amount 9,810',
      );
    });

    test(
        'bounds a row to roughly one line-height even when many fragments '
        'each individually pass the center-distance check', () {
      // A real iOS scan produced one reconstructed line fusing a label
      // column, its value column, AND unrelated footer text — several
      // genuinely separate printed rows stitched into one. The
      // center-distance check alone compares each candidate to the row's
      // *running average*, which shifts as fragments join; with enough
      // fragments a slow walk away from the row's true position can each
      // individually stay within tolerance of that shifting average even
      // though the row's total span keeps growing. This is the safety net
      // that check doesn't provide: however many fragments join, and
      // however they're spaced, a genuine single printed row never spans
      // much more than one line-height top-to-bottom.
      final lines = [
        for (int i = 0; i < 14; i++) _line('F$i', 10, 100 + i * 2.6),
      ];
      final rows = reconstructReadingOrder(lines).trim().split('\n');
      expect(rows.length, greaterThan(1),
          reason: '14 fragments spanning ~34px (1.7 line-heights) is more '
              'than one printed row — the row-span cap must split it');
    });

    test('two-column FBR-POS receipt parses correctly after reconstruction',
        () {
      // Simulates exactly the ML Kit failure mode this module exists for:
      // the label column and amount column arrive as separate blocks (here:
      // separate fragments), but bounding boxes put each amount beside its
      // label. After reconstruction the parser must read this like any
      // inline receipt — keyword strategy, no trailing-block heuristics.
      final lines = [
        // Header rows.
        _line('MARHABA SUPERMARKET', 40, 10, width: 260),
        _line('NTN # 8024130', 60, 40, width: 180),
        _line('Date: 30-Jun-2026', 20, 70, width: 200),
        // Label column (one block in real scans).
        _line('Gross Total:', 10, 300),
        _line('POS Service Fee:', 10, 330),
        _line('Net Total:', 10, 360),
        _line('CashRecelved:', 10, 390),
        _line('Cash Back:', 10, 420),
        _line('G.S.T Value:', 10, 450),
        // Amount column (a later block in real scans).
        _line('455.00', 320, 301, width: 70),
        _line('1.00', 320, 331, width: 70),
        _line('456.00', 320, 361, width: 70),
        _line('1,000.00', 320, 391, width: 70),
        _line('544.00', 320, 421, width: 70),
        _line('24.41', 320, 451, width: 70),
      ];

      final text = reconstructReadingOrder(lines);
      final r = ReceiptParser.parse(text);

      expect(r.total, 456.00,
          reason: 'Net Total sits inline after reconstruction — '
              'CashRecelved 1,000.00 must not win');
      expect(r.tax, 24.41);
      expect(r.date, DateTime(2026, 6, 30));
      expect(r.merchant, 'Marhaba Supermarket');
    });
  });

  group('ReceiptParser — OCR digit-confusion repair', () {
    test('repairs lookalike characters inside amount-shaped tokens', () {
      const raw = '''
QUICK SHOP
Item A          605.D0
Item B          120.00
Total           725.D0
''';
      final r = ReceiptParser.parse(raw);
      expect(r.total, 725.00, reason: '"725.D0" is 725.00 with D misread');
    });

    test('does not touch barcodes or plain integers', () {
      const raw = '''
MINI MART
8964000O7411
Item            9.99
Total           9.99
''';
      final r = ReceiptParser.parse(raw);
      expect(r.total, 9.99,
          reason: 'the barcode with a lookalike O has no amount shape and '
              'must not be rewritten into a giant amount');
    });
  });
}
