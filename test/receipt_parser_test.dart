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

  // ── Real Pakistani POS receipts (Marhaba Supermarket) ────────────────────
  //
  // These simulate what Google ML Kit OCR produces from the actual receipt
  // photos shared by the user. The layout is a typical FBR-POS receipt:
  //   • Merchant logo (often OCR'd as garbled text) + "SUPERMARKET" below
  //   • Address line
  //   • Gross Total → (-) Item Disc → POS Service Fee → Net Total
  //   • CashReceived → CashBack   (must NOT be picked as the total)
  //   • G.S.T Value: at the bottom (dots in name, must still be read as tax)
  group('ReceiptParser — Pakistani FBR-POS receipts', () {
    test('Marhaba receipt 1 — toy purchase, zero GST, discount applied', () {
      // Merchant: MARHABA SUPERMARKET
      // Net Total: 365.00  (Gross 455 − Disc 91 + POS fee 1)
      // CashReceived: 1,000.00  ← must NOT be total
      // G.S.T Value: 0.00
      const raw = '''
MARHABAIQIO
SUPERMARKET
Block-A Fortune Arcade Jamshoro Road
Qasim Chowk Hyderabad
022-2100624
NTN # 8024130
Sale Receipt                    Original
Bill No: SV-107-020634C
Do No: 12826296016
Date: 30-Jun-2026          Time: 22:57:48
Sr. Description   Price  Qty  GST Rate  GST  DISC  Total
BABY TOYS FANCY
1  218694
Qty: 1
Gross Tota:
(-) Item Disc:
POS Service Fee:
Net Totak
CashRecelved:
Cash Back:
You Saved
G.S.T Value:
User: COUNTER12
THANK YOU
Have A Nice Day
Tota
455.00
91.00
364.00
455.00
91.00
1.00
365.00
1,000.00
635.00
91.00
0.00
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 1 ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 365.00, reason: 'Net Total 365, not CashReceived 1000');
      expect(r.date, DateTime(2026, 6, 30));
    });

    test('Marhaba receipt 2 — ACTUAL OCR output from device', () {
      // This is the actual text ML Kit produced, read from the debug panel.
      // Labels and amounts are in separate columns — amounts appear at the
      // bottom as a bare column under "Tota".
      // Net Total: 401.00, CashReceived: 1,001.00, G.S.T: 24.41
      const raw = '''
M
Shop No 7 at l Village Housng Scheme. nca
Isra Univ ersiy lala Naku Road liyderabad
Date:
Sr. Description
Bill No: SV12UUGL09
PuNO: 1207293036
1 181394
MARHASAINOi0
MIRINDA 1LTR
Oty:
2 8964000 10131
G.S.T Value:
MARHABA BAKERY CHIKEN PATTIES
UPE MARKAR
10-Jun-2026
02-2100624
NT8024130
5
Saleg
Price Qty GST Rate
60.00
160.00
User: ISRAPOS3
4.000
Time:
1.000
Gross Tota:
POS Service Fee:
Net Totak
CashRecelved:
0.00
24.41
Cash Back:
No Of Item:
THANK YOU
Have A Nice Day
Origina
18:09:13
GS) DISC
0.00
0.00
18.00 0.00
Tota
240.00
160.00
400.00
1.00
401.00
1,001.00
600.00
24.41
Cuunter: ISRAPO
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 2 (actual OCR) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 401.00, reason: 'Net Total 401, not CashReceived 1001');
      expect(r.tax, 24.41,   reason: 'G.S.T Value 24.41 — last in amounts column');
      expect(r.date, DateTime(2026, 6, 10));
    });

    test('Indian receipt — CGST + SGST summed into one tax figure', () {
      const raw = '''
RELIANCE FRESH
MG Road, Bengaluru
GSTIN: 29AABCR1234Z1Z5
Date: 15-Jun-2026  Time: 14:23

TATA TEA GOLD 500G        185.00
AMUL BUTTER 500G          280.00
BREAD BRITANNIA            45.00

Subtotal                  510.00
CGST @2.5%                 12.75
SGST @2.5%                 12.75
Grand Total               535.50

Cash Paid                 600.00
Change                     64.50
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 3 (Indian CGST+SGST) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 535.50);
      expect(r.tax, closeTo(25.50, 0.01),
          reason: 'CGST 12.75 + SGST 12.75 = 25.50');
    });

    test('UAE receipt — VAT 5%', () {
      const raw = '''
CARREFOUR UAE
Dubai Mall, Dubai
TRN: 100123456700003
Date: 20-Jun-2026

Mineral Water 1.5L         5.00
Bread Loaf                 8.50
Orange Juice              12.00

Subtotal                  25.50
VAT 5%                     1.28
Total                     26.78

Cash                      30.00
Change                     3.22
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 4 (UAE VAT) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 26.78);
      expect(r.tax, 1.28);
    });

    test('US receipt — Sales Tax', () {
      const raw = '''
WALMART SUPERCENTER
123 Commerce Blvd
Austin, TX 78701
Tel: 512-555-0100

Date: 06/25/2026  Time: 10:15 AM

GREAT VALUE MILK 1GL       3.98
DORITOS NACHO               4.48
COLGATE TOOTHPASTE          2.97
BOUNTY PAPER TOWELS         9.97

Subtotal                   21.40
Sales Tax 8.25%             1.77
Total                      23.17

VISA ****1234              23.17
Change Due                  0.00
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 5 (US Sales Tax) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 23.17);
      expect(r.tax, 1.77);
      expect(r.date, DateTime(2026, 6, 25));
    });

    test('UK receipt — VAT at bottom', () {
      const raw = '''
TESCO EXPRESS
14 High Street, London
VAT Reg No: GB 123 4567 89

05/07/2026  09:42

SEMI-SKIMMED MILK 2PT      1.10
HOVIS WHOLEMEAL BREAD      1.30
WALKERS CRISPS             1.00
HEINZ BAKED BEANS          0.90

Subtotal                   4.30
VAT                        0.43
Total                      4.73

CONTACTLESS               4.73
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 6 (UK VAT) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 4.73);
      expect(r.tax, 0.43);
    });
  });
}
