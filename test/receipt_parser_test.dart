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
      expect(r.total, 14.99,
          reason: 'digit-confusion repair turns "l4.99" into 14.99');
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

    test('Marhaba receipt 3 — ACTUAL OCR, two trailing-amount clusters', () {
      const raw = '''
M
Dhop No 7 at Isra Vllage Housing Scheme, near
tsTa University Hala Naka Road Hyderabad
1 896400007411
-4
MARHABA O0
8ill No: SV-132-0152811
SUPERMA K
Do No: 1221577036
03-Jul-2026
Date:
2 527339777900
Qty:
022-2100624
NTN # 8024130
G.S.T Value:
Sale Receipt
2
Sr. Description
ADAMS CHEDDAR CHEESE SLICES 200GM
1.000
605.D0
LASEFA CUT BURGER
Price
120.00
Time:
1, 000
User: ISRAPOS1
GST
Qty GST Rate
Gross Totak
POS Sevice Fee:
FBR Invaice #
O.Q0
No Of Item:
Net Totak
Cash Recelved:
18.00
92.29
FHRE
POS
Cash Back:
Have Nica Day
20:09:18
0.00
original
DISC
CHEC
0.00
NO CASH REFUNDS
PER
Toia
605.00
2
120.00
725.00
1.00
726.00
730.00
Counter: ISRAPO
4.00
92.29
T8I 70GFG3T9202053
NO RETURN OR EXCHANGE WITHOUT AECEIPT
·NO EXCHANGE AFTER 7 DAYS OF PURCHASE
-FREE HOME DELIVERY ONLY ISRA VILLAGE RESIDENCE
Terms And Candltden
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 7 (Marhaba, actual OCR from real device) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 726.00,
          reason: 'Net Total 726 (Gross 725 + POS fee 1), not the '
              'shorter 18.00/92.29 cluster right after Cash Received');
      expect(r.date, DateTime(2026, 7, 3));
    });

    test('Al Fajr Foods receipt — ACTUAL OCR, dd/MM date ambiguity', () {
      const raw = '''
Al FAJR FOODS
SHOP2 3, 4 5 HOUSE # 46/D UNIT NO7
SNTN 2822467-1
07:22 PM
Take Away
Date : O1/07/2026 Time :
pos3
User :
pos3
300111
Token NO#:
Walking Customer
Order of :
Amt
Rate
Item Name
Qty
1080
300
CHICKEN BIRYANT
DOUBLE
3
1,080.00
0.00
Sub Total
1,080.00
Net Bill :
CASH
Received
0
1,080
Cash Returned
Thank You!
01/07/2026
7:22:17 PM
ware Developed By
th 0333-2602502
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 8 (Al Fajr Foods, actual OCR from real device) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.merchant, 'Al Fajr Foods');
      expect(r.total, 1080.00);
      expect(r.date, DateTime(2026, 7, 1),
          reason: '01/07/2026 is dd/MM (1 Jul) on a Pakistani NTN receipt, '
              'not MM/dd (Jan 7)');
    });

    test('Zar Tex receipt — ACTUAL OCR, whole-rupee amounts with no decimals', () {
      // Ground truth confirmed independently via the card payment slip for
      // the same transaction: SALE 9,810.00.
      const raw = '''
SW
Business Name: ZAR TEX (PRIVATE) IMITED
AUIO BA IN SHOP
PlutB 1/9,Main Autotalu koad, Heclsocity uH31alab
Tiydebad, pakisla.
POSID: 1/8936
Telepbone No: 022 6125862
NINH92497
SliiN 3 178761 s66 54
TBR voice H: 189 361 GTR2341/026
Date : 01/07/2026
SABI010/26 00037
Shoiub
(ustonier
OntH 9233625I9648
(NILNIN:
Value lnct
GST
AM
Excl 5ST%%
Valua
a5T
DAh 1 BLUE SlIOP A((ESSORLS BAG Size PS
Product
005221I
Price
Qty
2.00
2,/00
412
2,283
WONS 440 NAVY UNSTIEDUS 3PCS bie:sUT
2,342
|.00
0146130
254
336
Wil2P 6/20FURPLISTTB|UL UNSTILDUS PS Size:SU||
0148344
2,00
412
PS Sze:SUI
2,288
I,864
254
2,542
1,864
WIINS /o6/ Ri DUNSTICILD US
1 (00
1.00
0154455
18
1,864
WU2P 6811 BIAK UNSlOLDUS 2S Sice:S0T
015/05.i
1,864
1.00
9,009
1,497
B,312
TOTAL
No. ol llens
Add: Qher ch ges (il any)
Service tee
9a10
tu her lax / WI
Iotal net amoal
(ash
9,810
chatge
CARD #
1221
Iayval
Balance Amont
ER
9966 and win excittng prizes in dr aw
Verity ths invalce tht ough FBR TaxAsaan MobileApp ar SMS at
POS Software: Unicon International Pvt Ltd.
pf taxes
''';
      final r = ReceiptParser.parse(raw);
      print('\n--- Receipt 9 (Zar Tex, actual OCR from real device) ---');
      print('Merchant : ${r.merchant}');
      print('Total    : ${r.total}');
      print('Tax      : ${r.tax}');
      print('Date     : ${r.date}');

      expect(r.total, 9810.0,
          reason: 'Whole-rupee amount with no decimal point ("9,810"), '
              'confirmed against the card payment slip for this transaction');
    });

    test('Zar Tex receipt — merchant label misread as "Business Nane:"', () {
      // Real device scan (KAN-3/KAN-9). OCR drops the 'm' in "Name", and the
      // business-name line ends up scored below a garbled address line at
      // the top of the receipt unless it's recognized as an explicit label.
      const raw = '''
tot8 /y, Mn Autotbale fond, tecsocty
wael
tiyler alval, pakistar
OSHE 1/89 6
Business Nane: ZAR TEX (PRIVATE) (IMITED
NINNI912497
Aet#
(stone: Shokl
(Ni /NIN. 0
SABIO10/% 00
Product Qty Price Disc
2.00
TOTAL
Iaysal
AUO BAIIN SOF
BAG 1) BLUE SIIOP Af\$SORIE S BAG Sİze :P(S
o052211
4
1.00
No. of ltenns
bate 01/at/2026
WUNS /440 NAVY UNSTID US 3PCS bize: sUTI
0146130
1.00 2,542 254 2,288 18 412
WUNS /667 i) UNSTCHD0S 3 PC6 Sİze :SUI
015443,
1 (00 2,542 254 2, 288 18
Se vice fee
Contact#† 9235625/9648
Value
WiJ2P G!20 FURPUSTTBIUL UNSTHDUS 2PC5 Size :SU|
0148344
1.00! 1,864
1,864 18 336
(ash
STiNH 864 566 54
WU2P 6811 BIAK UNSTIEDUS 2PS Size:5/||
0157053
1,864
1.00
GST
Total nel dnount
Change
1221
(ARD #
Exc (GST%
Add: Othe ch ges (il any)
tuu the lax / WI!
18
8,312
GST
Amt
18
412
336
Value inci
GST
1,49/
2,/00
2,21)
2,700
2,0
9,309
0
9,010
9,810
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Zar Tex (Private) (Imited',
          reason: '"Business Nane:" (OCR-dropped "m") must still be '
              'recognized as a label and stripped, and the resulting line '
              'must win over the garbled address line above it');
      expect(r.total, 9810.0,
          reason: 'trailing block here has no clean CashBack arithmetic '
              'match; the biggest-non-excluded-amount fallback must still '
              'land on the real total rather than an unrelated scattered '
              'figure or the flagged-as-change 9,309/9,010 entries');
    });

    test('Zar Tex receipt — "TOTAL" column header must not be read as the '
        'bill total', () {
      // Real device scan. The item table's own "Total" column header lands
      // on its own OCR line, immediately followed by a bare "2.00" that is
      // actually the first item's quantity — without recognizing the
      // surrounding "Qty Price Disc" fragment as a header, this reads as an
      // inline total of 2.00.
      const raw = '''
POSD 1/89 6
Business Name:ZAR TEX (PRIVATE) LIMITED
PlotB 1/9, Main Aulutahui Road, Redsocity uitS
Ilyder albd, pakista.
Ielephone No: 022 6125862
NINI912497
BR voice #: 1/89 360GlR2341/826
(Ustone : Shoub
Product
(NI /NN: 0
SABI010/26 0003/
TOTAL
Qty Price Disc
2.00
taysal
AOBAL IN SUOP
BAG 11 BLUE SHOP A{ CESSORIFS BAG Size :PS
005221I
4
1.00 1,864
WUNS 7440 NAVy UNSTI|t2US 3PCSSize :SU|
014613O
1.00 2,342 254 2,288 18 412
WiW2P 6/ 20 FURPUSTB0L UNSIOHOIS 2PCSSjze :sUli
0148344
1 00 2,542 254
WINS /b6 kiDUNSTIHEDUS 3PCS Sİze :SU|
0154435
6
1.00 1,864 0
No. ot ltems
WU2P 6811 BLAK UNSTICHDUS 2 POS Size:SUW
015705:3
bate: 01/0//202t
Service fee
(ontac#. 923362519648
Futher Iax / W!I
Cash
Value
Excl (GST%
lotal net dnount
Change
1221
Add: Qe chau ges (il any)
GST
Amt
1,864 18 336
2,288 18 412
1,864 18 336
8,312
Value inci
GST
1,49/
2,/00
2,203
2,/00
2,200
9,809
1
9,810
9,#10
''';
      final r = ReceiptParser.parse(raw);
      expect(r.total, 9810.0,
          reason: 'the isolated "TOTAL" line right after the item table is '
              'a column header, not the bill total — must not be read as '
              '2.00 from the quantity fragment that follows it');
    });

    test('Zar Tex receipt — trailing block ends in the real total even '
        'after a jump from an unrelated scattered figure', () {
      // Real device scan. No clean CashBack triple in this trailing block;
      // the parser must not exclude the final (correct) trailing amount as
      // "likely change" just because a smaller unrelated figure precedes it.
      const raw = '''
IOSD /8936
Business Nanie: ZAR TEX (PRIVATE) IIMITED
PotWB 15/9, Maii Aulolkais Rod, Recsoily tLtdd
tlyder abal, pakista
lelephone No 022 61262
NINI912497
Rot:
BR vOice #: 1/896GR2341/82
(ustoner : Shoiub
(NIL /NN.
SABI010/26 000/
Product Qty Price DisG
TOTAL
2.00
Iaysal
AUIO BA IN SIIOP
BAG 11 BLUE STIGP A(CESSORIL 5 BAG Size PS
O052211
4
1.00
Balance Aiont
WUNS 7440 NAVY UNS||LILD US 3PS Size:SII
0146130
1.00 2,34? 254 2,288 18 412
WUNS /66/Ri) UNSTIO LDUS 3 P6 Sİze :SUII
015443%
1.00 2,542 254 2,288 18
1,864
No. of ems
WU2P b8]| BIA(K UNSTIHDUS 2P(S Size: SU
0157053
WiJ2P 6/20 FURPLISILB0L UNSIHDUS PCS Size: SU1
0148344
1.00 1,864 0 1.864 18
Service f ee
1221
Date 01/0//2024
tuther lax / W!!
(ARD #
STiIN# 2 116164 566 54
Contact #. 92336 25/964S
Value
lotal nel anount
ash
(hatnge
Exc (STY
GST
Add: Ole chtges (il y)
18
GST
Amt
8,312
1
336
1,864 18 336
412
Value inci
GST
1,497
2, /00
2,20)
2,/00
2,00
9,809
1
9,010
9,810
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Zar Tex (Private) Iimited');
      expect(r.total, 9810.0,
          reason: 'must not exclude the final trailing amount as "likely '
              'change" just because 9,010 (unrelated noise) precedes it '
              'with a jump greater than 50');
    });

    test('Marhaba SaleReturn receipt — real device scan, adjacent Total '
        'labels must not look like a scrambled table header', () {
      // Real device scan, first test on the arm64 release build after the
      // spatial-reconstruction fix. This layout inlines label+amount
      // cleanly ("Net Total: 605.00"), but "Gross Total:", "Total Disc:"
      // and "Net Total:" all sit within a few lines of each other — the
      // column-header window check must not mistake three legitimate
      // "Total" labels for a scrambled item-table header.
      const raw = '''
Marhaba SuperMarket (I
Block-A Fortune Arcade Jamshoro Road Qas
0306-4028830
SaleReturn Receipt
Inv#: 303,632,036
Date: 73/2026 8:08:28PM
Description Qty Price Total
ADAMS CHEDDAR CHEESE 200GM
1 605 605
Total Qty 1.00
Gross Total: 605.00
(-) Total Disc: 0.00
(+) Misc: 0.00
Net Total: 605.00
User: ISRAPOS1
30363203
Customner:
Contact No:
THANK YOU FOR YOUR VISIT
Software Developed by Mult-Tec.
Ph. 34551261
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Marhaba Supermarket (I');
      expect(r.total, 605.00,
          reason: '"Net Total: 605.00" must win — the nearby "Gross Total:" '
              'and "Total Disc:" are legitimate summary lines, not a '
              'scrambled item-table header, even though all three contain '
              'the word "total" within a few lines of each other');
    });

    test('Marhaba receipt — real device scan, "GST" column header must not '
        'be read as a tax label, and split logo+business-type merges', () {
      // Real device scan from the debug build (ocr_debug_logs id 10).
      // "Date: GST DISC" is a column-header fragment ("Price Qty GST Rate"
      // split across reconstructed rows) that contains the word "GST" —
      // must not be treated as a real tax label the way "G.S.T Value:"
      // later on the receipt is. Also: the store logo "AARHABA..." and
      // "SUPERMARKET" print as two separate lines and must be merged into
      // one merchant name rather than scored as independent candidates.
      const raw = '''
AARHABAlLO0
S UPERMARKET
Shop No 7at Isra illage Housing Scheme, near Isra University Hala Naka Road Hyderabad
022-2100624
NTN # 8024130
Sale Receipt Origlnal
Bill NO: SV-133-0062781 1223028036 22:35:34
Do No: Time: Toto
05-Jul-2026
Date: GST DISC
Price Qly GST Rate
Sr. Description
70.00
SLICE JUICE MANGO 355ML BTL 18.00 0. 00
1.000 9.92
70.00
1 B964O0010142
295 D0
ZIDELLO DUST PAN RUBBER STRIP SUPRI
35. 8s
295.00 1.000
2 530072001235
2
No of item:
2
Qty:
305.00
Gross Totak
1.00
POS Servlce Fee:
306.00
Net Totat
CashRecelved: 1,000.00
CashBack: 694.00
G.S.T Value: 45.76
User: ISRAPOS2 Courter. ISRAPO
THANK YOU
Have A Nice Day
FER
POS
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, 'Aarhaballo0 Supermarket',
          reason: 'the store-type suffix word on its own line must merge '
              'with the logo line above it rather than being scored as an '
              'unrelated candidate; the logo text itself ("AARHABA" for '
              '"MARHABA") is a genuine dropped-letter misread with no '
              'label to recover it from, and is not expected to be exact');
      expect(r.total, 306.00,
          reason: 'confirmed independently: CashReceived 1,000.00 − '
              'NetTotal 306.00 = CashBack 694.00 exactly');
      expect(r.tax, 45.76,
          reason: '"Date: GST DISC" (a column header, not a tax line) must '
              'not contribute to the tax figure — only "G.S.T Value: '
              '45.76" is real');
      expect(r.date, DateTime(2026, 7, 5));
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

    test(
        'Marhaba receipt — logo line with a single leading OCR-noise '
        'character must still beat a cleaner runner-up fragment', () {
      // Real device scan: line 0 is the true logo ("3MARHABALO)" — a
      // misread symbol/digit glued onto "MARHABA"), line 1 is a garbled
      // "SUPERMARKET" fragment that used to win purely for being short and
      // 100% letters. The receipt otherwise doesn't matter for this test.
      const raw = '''
3MARHABALO)
SUEERE
Shop No 7 at Isra Village Housing Scheme, ne
Isa University Hala Naka kond Hyderabad
022-2100624
NTN # 8024130
Sale Receipt                    Original
Bill No: SV-133-0062090
Do No: 1221976036
Date: 04-Jul-2026          Time: 15:03:08
Total
250.00
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, contains('Marhaba'));
    });

    test(
        'Marhaba receipt — metadata fragment merged onto the logo row by '
        'OCR must be stripped from the merchant', () {
      // Real device scan: ML Kit put "Sale Re" (a fragment of the
      // "Sale Receipt" header) on the same visual row as the logo, so the
      // merchant candidate line itself arrived as "SARHABALOLO Sale Re".
      const raw = '''
SARHABALOLO Sale Re
S3300655
Shop No 7 at Isra Village Ilousing Scheme, ne ar
1sra University Hala Naka koad Hy derabad
022-21o0624 NTN # 802413o
Do No: Sale Receigt
04-Jul-2026
Gross Tota:
150.00
Net Total
159.00
''';
      final r = ReceiptParser.parse(raw);
      expect(r.merchant, isNot(contains('Sale')));
      expect(r.merchant, contains('Sarhabalolo'));
    });
  });
}
