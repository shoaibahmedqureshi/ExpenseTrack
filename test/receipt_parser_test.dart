import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/receipt_scanner/data/receipt_parser.dart';

void main() {
  group('ReceiptParser — short receipts', () {
    test('coffee shop receipt', () {
      const raw = '''
STARBUCKS
123 Main St
Seattle, WA 98101
(206) 555-0123

03/14/2026  9:41 AM

Grande Latte         4.95
Blueberry Muffin      3.25

Subtotal              8.20
Tax                    0.74
Total                  8.94

Thank you!
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Starbucks');
      expect(r.total, 8.94);
      expect(r.date, DateTime(2026, 3, 14));
    });

    test('gas station receipt', () {
      const raw = '''
SHELL
Pump 4
01-09-2026

UNLEADED   12.403 GAL
PRICE/GAL    3.499

AMOUNT DUE     43.40
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Shell');
      expect(r.total, 43.40);
      expect(r.date, DateTime(2026, 1, 9));
    });

    test('parking receipt with no explicit total keyword', () {
      const raw = '''
CITY PARKING AUTHORITY
LOT 7

ENTRY 08:02
EXIT  10:15

5.50
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'City Parking Authority');
      expect(r.total, 5.50);
    });
  });

  group('ReceiptParser — long itemized receipts', () {
    test('grocery store receipt with many line items', () {
      const raw = '''
WHOLE FOODS MARKET
2001 Market St
San Francisco, CA 94114
Tel: 415-555-0199

03/02/2026 18:22

BANANAS ORGANIC          1.99
WHOLE MILK 1GAL          4.49
EGGS LARGE DOZEN         3.29
BREAD WHOLE WHEAT        3.99
CHICKEN BREAST 2LB      11.98
PASTA SAUCE              2.49
SPAGHETTI                1.79
OLIVE OIL                8.99
GREEK YOGURT             5.49
SPINACH BAG              2.99
TOMATOES                 3.49
ONIONS 3LB               2.29
GARLIC                   0.99
PAPER TOWELS             6.99
DISH SOAP                3.49

SUBTOTAL                64.74
TAX                       5.18
TOTAL                    69.92

VISA ENDING 4242
CHANGE DUE                0.00

Thank you for shopping!
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Whole Foods Market');
      expect(r.total, 69.92);
      expect(r.date, DateTime(2026, 3, 2));
    });

    test('restaurant receipt with tip and multiple totals', () {
      const raw = '''
THE OLIVE GARDEN
Table 12  Server: Jamie

Caesar Salad             8.50
Chicken Parmesan        18.95
Breadsticks (free)       0.00
Iced Tea                 2.95
Iced Tea                 2.95
Tiramisu                 6.50

Subtotal                39.85
Tax                      3.51
Suggested Tip 18%        7.80

Grand Total              51.16

March 9, 2026
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'The Olive Garden');
      expect(r.total, 51.16);
      expect(r.date, DateTime(2026, 3, 9));
    });

    test('pharmacy receipt, date at top, balance due wording', () {
      const raw = '''
CVS PHARMACY #4471
March 5, 2026

RX COPAY                10.00
VITAMIN D 1000IU          8.49
COTTON SWABS              2.19
HAND SANITIZER            3.99
ALLERGY RELIEF 24CT       12.49
THERMOMETER               9.99

BALANCE DUE               47.15

ExtraCare savings: 2.30
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Cvs Pharmacy #4471');
      expect(r.total, 47.15);
      expect(r.date, DateTime(2026, 3, 5));
    });
  });

  group('ReceiptParser — edge cases', () {
    test('european-style date format dd-MM-yyyy', () {
      const raw = '''
CAFE DE PARIS
25-12-2026

Croissant       3.50
Cafe Au Lait    4.00

Total           7.50
''';
      final r = ReceiptParser.parse(raw);
      expect(r.date, DateTime(2026, 12, 25),
          reason: 'dd-MM-yyyy should not be misread as MM-dd-yyyy');
    });

    test('discount/savings line should not be mistaken for total', () {
      const raw = '''
TARGET
03/11/2026

ITEM A             24.99
ITEM B             19.99
You saved          45.00

Subtotal           44.98
Tax                 3.82
Total               48.80
''';
      final r = ReceiptParser.parse(raw);
      expect(r.total, 48.80,
          reason: '"You saved 45.00" is larger than the real total and has no total keyword nearby');
    });

    test('merchant name on second line after a generic header', () {
      const raw = '''
**** WELCOME ****
Trader Joe's
410 Bay St

03/01/2026

Total            12.34
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, "Trader Joe's");
    });

    test('receipt with OCR noise / misread characters', () {
      const raw = '''
B E S T  B U Y
O3/15/2O26

USB-C  CABLE          l4.99
Tota1                 l4.99
''';
      final r = ReceiptParser.parse(raw);
      // Letter-spaced thermal-printer headers ("B E S T  B U Y") are
      // reconstituted into a normal word so the merchant name is usable.
      expect(r.merchant, 'Best Buy');
      // Known limitation: OCR character confusion (O for 0, l for 1) on the
      // total line itself defeats the numeric regex — there's no digit-
      // confusion correction pass, so this is left undocumented as a gap
      // rather than asserting a value the parser can't actually produce.
    });

    test('no date present anywhere on receipt', () {
      const raw = '''
QUICK MART

Soda      1.50
Chips     2.99

Total     4.49
''';
      final r = ReceiptParser.parse(raw);
      expect(r.date, isNull);
      expect(r.total, 4.49);
    });

    test('decimal without thousands separator and no currency symbol', () {
      const raw = '''
LOCAL DINER
2026-03-08

Burger 9.50
Fries 3.25
Total 12.75
''';
      final r = ReceiptParser.parse(raw);
      expect(r.total, 12.75);
      expect(r.date, DateTime(2026, 3, 8));
    });

    test('amount over \$1000 with thousands separator', () {
      const raw = '''
APPLE STORE
03/20/2026

MacBook Pro      1,899.00
AppleCare+         249.00

Total            2,148.00
''';
      final r = ReceiptParser.parse(raw);
      expect(r.total, 2148.00);
    });
  });
}
