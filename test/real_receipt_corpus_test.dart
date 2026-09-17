// Accuracy benchmark against REAL device scans (from ocr_debug_logs).
//
// Unlike the per-receipt tests in receipt_parser_test.dart, this suite
// scores the whole corpus and fails only when field-level accuracy drops
// below the thresholds — so a genuinely unparseable receipt doesn't block
// CI, but a regression that breaks several receipts does. Per-receipt
// diffs are printed on every run for inspection.
import 'package:flutter_test/flutter_test.dart';

import 'package:outlay/features/receipt_scanner/data/receipt_parser.dart';
import 'real_corpus_cases.dart';

void main() {
  test('real-scan corpus accuracy: total ≥ 90%, merchant ≥ 80%, '
      'tax ≥ 70%, date ≥ 80%', () {
    int totalOk = 0, merchantOk = 0, taxOk = 0, dateOk = 0;
    int totalN = 0, merchantN = 0, taxN = 0, dateN = 0;
    final failures = StringBuffer();

    for (final c in cases) {
      final r = ReceiptParser.parse(c.raw);

      if (c.total != null) {
        totalN++;
        final ok = r.total != null && (r.total! - c.total!).abs() < 0.01;
        if (ok) {
          totalOk++;
        } else {
          failures.writeln(
              'id=${c.id} TOTAL expected ${c.total} got ${r.total}');
        }
      }

      if (c.merchantContains != null) {
        merchantN++;
        final ok = (r.merchant ?? '')
            .toLowerCase()
            .contains(c.merchantContains!.toLowerCase());
        if (ok) {
          merchantOk++;
        } else {
          failures.writeln(
              'id=${c.id} MERCHANT expected ~"${c.merchantContains}" '
              'got "${r.merchant}"');
        }
      }

      // Tax scored on every case: either matches the expected value, or is
      // correctly null when the receipt has no (readable) tax figure.
      taxN++;
      final taxExpected = c.tax;
      final taxGot = r.tax;
      final taxMatches = taxExpected == null
          ? taxGot == null
          : taxGot != null && (taxGot - taxExpected).abs() < 0.01;
      if (taxMatches) {
        taxOk++;
      } else {
        failures.writeln('id=${c.id} TAX expected $taxExpected got $taxGot');
      }

      if (c.date != null || c.dateNullOk) {
        dateN++;
        final ok = c.date == null
            // Unreadable date: null is right; a confidently-wrong guess
            // is still counted as wrong.
            ? r.date == null
            : r.date != null &&
                r.date!.year == c.date!.year &&
                r.date!.month == c.date!.month &&
                r.date!.day == c.date!.day;
        if (ok) {
          dateOk++;
        } else {
          failures.writeln('id=${c.id} DATE expected ${c.date} got ${r.date}');
        }
      }
    }

    final report = '''
── Real-scan corpus scorecard ─────────────────────
 total    : $totalOk/$totalN
 merchant : $merchantOk/$merchantN
 tax      : $taxOk/$taxN
 date     : $dateOk/$dateN
${failures.isEmpty ? ' (all fields correct)' : failures.toString()}''';
    // ignore: avoid_print
    print(report);

    expect(totalOk / totalN, greaterThanOrEqualTo(0.90), reason: report);
    expect(merchantOk / merchantN, greaterThanOrEqualTo(0.80), reason: report);
    expect(taxOk / taxN, greaterThanOrEqualTo(0.70), reason: report);
    expect(dateOk / dateN, greaterThanOrEqualTo(0.80), reason: report);
  });
}
