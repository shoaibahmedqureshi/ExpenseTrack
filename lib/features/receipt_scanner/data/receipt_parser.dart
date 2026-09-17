import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import '../domain/receipt_scan_result.dart';

/// Parses raw OCR text from a receipt into structured fields.
///
/// Supports two receipt layouts:
///   Inline  — label + amount on the same line  ("Net Total  401.00")
///   Split   — ML Kit reads multi-column POS receipts in column order.
///              Labels appear first with no amounts; all amounts appear later
///              as a bare column (typical for Pakistani FBR-POS receipts).
///
/// For split-column receipts:
///   • Collects the trailing block of bare amount lines at the end of the text.
///   • Net Total = the amount satisfying CashBack == CashReceived − NetTotal.
///   • Tax = the last unique amount after CashBack in the trailing block.
/// Result of a successful NetTotal/CashReceived/CashBack arithmetic match —
/// see [ReceiptParser._findNetTotalViaTriple].
class _TotalTriple {
  final double netTotal;
  final int cashBackIndex;
  const _TotalTriple({required this.netTotal, required this.cashBackIndex});
}

class ReceiptParser {
  ReceiptParser._();

  static ReceiptScanResult parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final trailingAmounts = _extractTrailingAmountsBlock(lines);
    final triple = _findNetTotalViaTriple(trailingAmounts);
    final likelyChangeAmounts = _likelyChangeAmounts(trailingAmounts);

    final result = ReceiptScanResult(
      rawText: rawText,
      total: _extractTotal(lines, triple, likelyChangeAmounts),
      tax: _extractTax(lines, trailingAmounts, triple),
      date: _extractDate(lines),
      merchant: _extractMerchant(lines),
    );

    dev.log(
      'trailingBlock=$trailingAmounts triple=${triple?.netTotal}\n'
      'merchant=${result.merchant} total=${result.total} '
      'tax=${result.tax} date=${result.date}',
      name: 'ReceiptParser',
    );
    return result;
  }

  // ── Amount regex ──────────────────────────────────────────────────────────

  // Requires two decimal places (X.XX or X,XXX.XX), OR a comma-grouped
  // whole number with no decimal (X,XXX) — some Pakistani retail receipts
  // print whole-rupee totals with no cents at all (e.g. "9,810"). The
  // comma-group is mandatory for the no-decimal case specifically so plain
  // integers (barcodes, quantities, invoice numbers) still don't match.
  // Deliberately excludes plain integers and tax-rate percentages (8.25%).
  static final _amountRe = RegExp(
    r'(?:rs\.?\s*|pkr\.?\s*|inr\.?\s*|aed\.?\s*|gbp\.?\s*|£\s*|\$\s*|€\s*)?'
    r'(\d{1,3}(?:,\d{3})+\.\d{2}|\d{1,3}(?:,\d{3})+|\d{1,3}\.\d{2})',
    caseSensitive: false,
  );

  // ── OCR digit-confusion repair ────────────────────────────────────────────
  //
  // Thermal-print digits are routinely misread as lookalike characters:
  // real device scans contained "605.D0" (605.00), "O.Q0" (0.00), "9,#10"
  // (9,810), "l4.99" (14.99). Repair is deliberately narrow so words and
  // barcodes are never touched — a token is rewritten only when it
  //   (a) already contains at least two real digits,
  //   (b) consists solely of digits, lookalikes, and amount punctuation,
  //   (c) parses as a money amount AFTER the swap (so "0052211" stays a
  //       barcode — no comma/decimal shape — while "9,#10" becomes 9,810).
  // '/' → '7' looks dangerous (dates!), but the full-token-must-become-a-
  // clean-amount guard below protects every date shape: "01/07/2026" maps
  // to "0170772026", which has no comma/decimal amount shape, so it's
  // rejected and left untouched — while "1,49/" (a real device misread of
  // 1,497) maps to the valid comma-grouped "1,497" and is repaired.
  static const _digitLookalikes = {
    'O': '0', 'o': '0', 'Q': '0', 'D': '0',
    'l': '1', 'I': '1', '|': '1',
    'B': '8', '#': '8',
    'Z': '2',
    '/': '7',
  };

  static final _nearAmountToken = RegExp(r'^[0-9OoQDlI|B#Z/,.]{3,}$');

  static String _repairConfusedDigits(String line) {
    return line.split(' ').map((token) {
      if (RegExp(r'\d').allMatches(token).length < 2) return token;
      if (!_nearAmountToken.hasMatch(token)) return token;
      final mapped = token
          .split('')
          .map((c) => _digitLookalikes[c] ?? c)
          .join();
      if (mapped == token) return token;
      final m = _amountRe.firstMatch(mapped);
      // Only trust the swap when the whole token became a clean amount —
      // partial matches would let noise through.
      return (m != null && m.group(0)!.length == mapped.length)
          ? mapped
          : token;
    }).join(' ');
  }

  static double? _largestAmountOnLine(String rawLine) {
    final line = _repairConfusedDigits(rawLine);
    double? best;
    for (final m in _amountRe.allMatches(line)) {
      // Skip if immediately followed by % — it's a rate, not a money amount.
      if (m.end < line.length && line[m.end] == '%') continue;
      final raw = m.group(1)!.replaceAll(',', '');
      final v = double.tryParse(raw);
      // Reject zero/sub-cent and barcodes.
      if (v != null && v >= 0.01 && v < 10000000) {
        if (best == null || v > best) best = v;
      }
    }
    return best;
  }

  /// Amount on [line] or on a nearby line (for split-column receipts).
  static double? _amountNearLine(List<String> lines, int index,
      {int lookahead = 3}) {
    final onSame = _largestAmountOnLine(lines[index]);
    if (onSame != null) return onSame;
    for (int off = 1; off <= lookahead && index + off < lines.length; off++) {
      final next = lines[index + off];
      if (_isBareAmountLine(next)) return _largestAmountOnLine(next);
      // Stop scanning forward if we hit another label keyword.
      if (_totalKeywords.hasMatch(next) ||
          _postTotalExclusion.hasMatch(next)) {
        break;
      }
    }
    return null;
  }

  static bool _isBareAmountLine(String rawLine) {
    final stripped = _repairConfusedDigits(rawLine)
        .replaceAll(_amountRe, '')
        .replaceAll(RegExp(r'[rs\$pkr£€]', caseSensitive: false), '')
        .trim();
    return stripped.isEmpty;
  }

  // ── Column-pair extraction ────────────────────────────────────────────────
  //
  // Some FBR-POS scans come out with a run of bare VALUES followed by the
  // run of ':'-terminated LABELS they belong to:
  //
  //     1.00          ← POS Service Fee
  //     250.00        ← Net Total
  //     1,000.00      ← Cash Received
  //     POS Service Fee:
  //     Net Total:
  //     CashRecelved:
  //
  // Forward-only lookup can never pair these. This aligns the label block
  // END-to-END with the bare-amount block directly above it, so extra
  // values at the front (belonging to earlier rows) drop away naturally,
  // and a label with no matching value returns null rather than guessing.
  //
  // Deliberately restricted to ':'-terminated labels: unpunctuated words
  // like a lone "TOTAL" are far more often scrambled table-column headers
  // whose neighbouring numbers are quantities, not money.

  static final _colonLabelRe = RegExp(r'[:：]\s*$');

  static double? _columnPairAmount(List<String> lines, int i) {
    if (!_colonLabelRe.hasMatch(lines[i].trim())) return null;
    if (_largestAmountOnLine(lines[i]) != null) return null;

    // Contiguous block of ':'-terminated, amount-free label lines around i.
    int top = i, bottom = i;
    bool isLabelLine(String l) =>
        _colonLabelRe.hasMatch(l.trim()) && _largestAmountOnLine(l) == null;
    while (top - 1 >= 0 && isLabelLine(lines[top - 1])) {
      top--;
    }
    while (bottom + 1 < lines.length && isLabelLine(lines[bottom + 1])) {
      bottom++;
    }

    // Bare-amount block immediately above the labels, in reading order.
    final values = <double>[];
    for (int v = top - 1; v >= 0; v--) {
      if (!_isBareAmountLine(lines[v])) break;
      final a = _largestAmountOnLine(lines[v]);
      // A zero-only line ("O.Q0" → 0.00) would silently shift every
      // pairing below it by one — bail out instead of guessing.
      if (a == null) break;
      values.insert(0, a);
    }
    if (values.isEmpty) return null;

    final posFromEnd = bottom - i;
    final idx = values.length - 1 - posFromEnd;
    return idx >= 0 ? values[idx] : null;
  }

  // ── Trailing amounts block ────────────────────────────────────────────────
  //
  // On split-column POS receipts ML Kit reads the rightmost "Total" column
  // last. We walk backwards from the end collecting the contiguous cluster
  // of amount lines that make up the summary section — deliberately *not*
  // every amount on the receipt, since the item table earlier on is full of
  // prices/rates that can coincidentally satisfy the arithmetic check below
  // and must not be allowed to compete with the real summary figures.

  static List<double> _extractTrailingAmountsBlock(List<String> lines) {
    // Find last line that has an amount.
    int end = lines.length - 1;
    while (end >= 0 && _largestAmountOnLine(lines[end]) == null) {
      end--;
    }
    if (end < 0) return [];

    final amounts = <double>[];
    int gaps = 0;
    int i = end;
    while (i >= 0 && gaps <= 2) {
      final a = _largestAmountOnLine(lines[i]);
      if (a != null) {
        amounts.insert(0, a);
        gaps = 0;
      } else {
        final line = lines[i];
        // Stop on clearly-content lines (not just a short label/keyword).
        if (line.length > 30 ||
            RegExp(r'[a-zA-Z]{4,}').allMatches(line).length > 2) {
          break;
        }
        gaps++;
      }
      i--;
    }
    return amounts;
  }

  /// Net Total found via CashBack == CashReceived − NetTotal, which holds
  /// exactly regardless of how small the NetTotal→CashReceived jump is.
  /// Scanned from the end backward so the real trailing triple wins over any
  /// coincidental match earlier in the block (e.g. duplicated price/discount
  /// figures). [cashBackIndex] is the position of CashBack within
  /// [amounts], used later to locate G.S.T/tax, which always comes right
  /// after it.
  static _TotalTriple? _findNetTotalViaTriple(List<double> amounts) {
    for (int i = amounts.length - 3; i >= 0; i--) {
      final netTotal = amounts[i];
      final cashReceived = amounts[i + 1];
      final cashBack = amounts[i + 2];
      if (cashReceived >= netTotal - 0.01 &&
          (cashReceived - netTotal - cashBack).abs() < 0.01) {
        return _TotalTriple(netTotal: netTotal, cashBackIndex: i + 2);
      }
    }
    return null;
  }

  /// Amounts that look like "money paid back to the customer" — anything a
  /// smaller amount jumps up to by more than 50 — even when no exact
  /// CashBack triple is found. The plain "biggest amount on the receipt"
  /// fallback has no keyword nearby to exclude these by, so without this a
  /// large CashReceived/CashBack can outrank the real total simply by being
  /// numerically bigger (the customer almost always hands over more than
  /// the bill, and gets some of it back).
  ///
  /// The final amount in the block is deliberately exempt: on every noisy
  /// real-world sample seen so far, whatever number ends up last in the
  /// trailing cluster is the real total (or close to it) even when earlier
  /// entries are unrelated scrambled noise — flagging it here would throw
  /// out the one candidate that's actually reliable.
  static Set<double> _likelyChangeAmounts(List<double> amounts) {
    final flagged = <double>{};
    for (int i = 1; i < amounts.length - 1; i++) {
      if (amounts[i] - amounts[i - 1] > 50) flagged.add(amounts[i]);
    }
    return flagged;
  }

  // ── Total ─────────────────────────────────────────────────────────────────

  // NOTE: prefix patterns (net\s*tota, grand\s*tota) intentionally have NO
  // trailing \b so they match OCR typos like "Net Totak" and "Gross Tota:".
  static final _totalKeywords = RegExp(
    r'\b(grand\s*total|amount\s*due|balance\s*due|total\s*due|'
    r'total\s*amount|total\s*bill|bill\s*total|net\s*payable|'
    r'net\s*amount|payable)\b'
    r'|\bnet\s*tota'    // handles "Net Total", "Net Totak", "Net Tota:"
    r'|\bgrand\s*tota'  // handles "Grand Total", "Grand Tota"
    r'|\btotal\b',
    caseSensitive: false,
  );

  // Lines AFTER the real total — never use their amounts as the bill total.
  // "cash\s*rec" has NO trailing \b so it tolerates OCR typos like
  // "CashRecelved"/"CashRecieved", where the boundary would otherwise never
  // land right after "rec". Everything else keeps exact word boundaries.
  static final _postTotalExclusion = RegExp(
    r'\bcash\s*rec'
    r'|\b(cash\s*back'
    r'|cash\s*change'
    r'|cash\s*paid'
    r'|change\s*due|change\s*given'
    r'|tender|paid\s*by'
    r'|card\s*(payment|amount|no\.?)'
    r'|visa|mastercard|master\s*card|amex|debit|credit'
    r'|loyalty|points?\s*(earned|redeemed)'
    r')\b',
    caseSensitive: false,
  );

  static double? _extractTotal(
    List<String> lines,
    _TotalTriple? triple,
    Set<double> likelyChangeAmounts,
  ) {
    // Strategy 1: keyword + inline/nearby amount (most receipts).
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (_postTotalExclusion.hasMatch(line)) continue;
      if (_totalKeywords.hasMatch(line)) {
        // Skip the item table's own "Total" column header — split-column
        // OCR can land it on its own line, isolated from the rest of the
        // header, right next to an item's price/qty fragment, which would
        // otherwise look exactly like an inline total.
        if (_isNearColumnHeader(lines, i)) continue;
        final amount = _amountNearLine(lines, i);
        if (amount != null) return amount;
        // Values printed BEFORE their labels (see _columnPairAmount).
        final paired = _columnPairAmount(lines, i);
        if (paired != null) return paired;
      }
    }

    // Strategy 2: CashBack-relation arithmetic signal, searched across
    // every amount on the receipt (not just a narrow trailing window) — for
    // FBR-POS split-column receipts where labels have no inline amounts.
    if (triple != null) return triple.netTotal;

    // Strategy 3: largest amount on any non-excluded line, additionally
    // skipping anything that looks like money handed back to the customer
    // (see _likelyChangeAmounts) even without an exact arithmetic match —
    // otherwise a big CashReceived/CashBack can outrank the real total by
    // simply being the largest number on the page, with no keyword nearby
    // to catch it.
    double? biggest;
    for (final line in lines) {
      if (_postTotalExclusion.hasMatch(line)) continue;
      final a = _largestAmountOnLine(line);
      if (a == null || likelyChangeAmounts.contains(a)) continue;
      if (biggest == null || a > biggest) biggest = a;
    }
    if (biggest != null) return biggest;

    // Strategy 4 (last resort): largest amount at all, even one flagged as
    // likely change — only reached when every non-change candidate above
    // was excluded and nothing else on the receipt produced a number.
    double? anyBiggest;
    for (final line in lines) {
      if (_postTotalExclusion.hasMatch(line)) continue;
      final a = _largestAmountOnLine(line);
      if (a != null && (anyBiggest == null || a > anyBiggest)) anyBiggest = a;
    }
    return anyBiggest;
  }

  // ── Tax ───────────────────────────────────────────────────────────────────

  static final _taxKeywords = RegExp(
    r'('
    r'\btax\b|\btaxes\b|\btax\s*amount\b|\btax\s*total\b'
    r'|\bvat\b|\bv\.a\.t\.?'
    // g.s.t with any subset of its dots present — real scans produce
    // "G.ST Value" (middle dot dropped) and "GS.T" alongside the clean
    // forms. \b before a dot never matches, hence the explicit variants.
    r'|\bgst\b|\bg\.s\.t\.?|\bg\.st\b|\bgs\.t\b'
    r'|\bcgst\b|\bc\.g\.s\.t\.?|\bsgst\b|\bs\.g\.s\.t\.?'
    r'|\bigst\b|\bi\.g\.s\.t\.?|\butgst\b'
    r'|\bhst\b|\bpst\b|\brst\b|\bqst\b'
    r'|\bsales\s*tax\b|\bstate\s*tax\b|\bcounty\s*tax\b'
    r'|\bcity\s*tax\b|\blocal\s*tax\b|\bfed\.?\s*tax\b'
    r'|\bfederal\s*tax\b|\bexcise\s*tax\b|\buse\s*tax\b'
    r'|\bservice\s*tax\b|\bservice\s*charge\b'
    r'|\bsts\b|\bfurther\s*tax\b|\bwithholding\s*tax\b|\bwht\b'
    r'|\bsindh\s*sales\s*tax\b|\bpunjab\s*sales\s*tax\b'
    r'|\bcess\b|\bconsumption\s*tax\b|\bjct\b'
    r'|\bicms\b|\biss\b|\bipi\b|\bpis\b|\bcofins\b'
    r')',
    caseSensitive: false,
  );

  static final _taxRegNoRe = RegExp(
    r'\b(reg\.?\s*no\.?|registration|gstin|trn|ntn|tin|ein|abn|'
    r'vat\s*(reg|no|number|registration)|tax\s*(id|no|number|code))\b',
    caseSensitive: false,
  );

  // Column headers on heavily column-scrambled OCR are often split across
  // several short lines rather than sitting on just one or two adjacent
  // ones, and the header fragment can land either before or after the
  // isolated "Total"/"Tax" word depending on how ML Kit reassembled the
  // columns. Sum keyword hits across a window around [i] instead of just
  // checking the immediately-preceding line.
  //
  // Deliberately excludes "total" itself from this window count: a real
  // summary section legitimately repeats it several times close together
  // ("Gross Total:", "Total Disc:", "Net Total:"), which would otherwise
  // look exactly like a scrambled header. Only *other* column words —
  // Qty, Price, Disc, Description — sitting near this specific "Total" are
  // real evidence it's a header fragment rather than the bill total.
  static final _nonTotalColumnHeaderRe = RegExp(
    r'\b(sr\.?|description|product|price|qty|quantity|rate|disc(?:ount)?|'
    r'no\.?\s*of\s*item)\b',
    caseSensitive: false,
  );

  static bool _isNearColumnHeader(List<String> lines, int i) {
    int hits = _nonTotalColumnHeaderRe.allMatches(lines[i]).length;
    for (int off = 1; off <= 3; off++) {
      if (i - off >= 0) {
        hits += _nonTotalColumnHeaderRe.allMatches(lines[i - off]).length;
      }
      if (i + off < lines.length) {
        hits += _nonTotalColumnHeaderRe.allMatches(lines[i + off]).length;
      }
    }
    return hits >= 2;
  }

  // "G.S.T Value:" / "Tax Amount:" style summary labels — the receipt
  // explicitly labelling a figure. These are never column headers, so the
  // windowed header check must not discard them just because a stray
  // "Sr. Description" fragment landed nearby in scrambled OCR.
  static final _labeledTaxValueRe = RegExp(
    r'\b(value|amount|amt)\s*[:：]',
    caseSensitive: false,
  );

  static double? _extractTax(
    List<String> lines,
    List<double> trailingAmounts,
    _TotalTriple? triple,
  ) {
    // Strategy 1: keyword + inline/nearby amount.
    //
    // Grouped by canonical keyword ("g.s.t" and "GST" both → "gst"), and
    // only the LAST hit per keyword is kept: on column-scrambled receipts
    // the same keyword appears several times as table-column fragments
    // ("GST Amt" column, "Value incl GST" column) before the real summary
    // figure, and summing those fragments produced wild totals like
    // 8,312 + 1,497 on real scans. Distinct keywords still sum, which is
    // what multi-tax receipts (CGST + SGST) actually need.
    final lastByKeyword = <String, double>{};
    bool hasUnresolvedTaxLabel = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final kwMatch = _taxKeywords.firstMatch(line);
      if (kwMatch == null) continue;
      if (_taxRegNoRe.hasMatch(line)) continue;
      // Skip table column headers like "Price Qty GST Rate" — these are
      // often split across lines by column-scrambled OCR, and "GST" is
      // itself one of the column names, so this needs the same windowed
      // header check as total extraction, not just a same-line count.
      // Explicitly labelled values ("G.S.T Value:") are exempt — see
      // _labeledTaxValueRe.
      if (!_labeledTaxValueRe.hasMatch(line) &&
          _isNearColumnHeader(lines, i)) {
        continue;
      }

      final amount = _amountNearLine(lines, i, lookahead: 3) ??
          _columnPairAmount(lines, i);
      if (amount != null) {
        final canonical = kwMatch
            .group(0)!
            .toLowerCase()
            .replaceAll(RegExp(r'[.\s]'), '');
        lastByKeyword[canonical] = amount;
      } else {
        hasUnresolvedTaxLabel = true;
      }
    }

    if (lastByKeyword.isNotEmpty) {
      return lastByKeyword.values.reduce((a, b) => a + b);
    }

    // Strategy 2: tax is the last unique amount after CashBack, searched
    // across every amount on the receipt. On FBR-POS receipts the order is
    // [..., NetTotal, CashReceived, CashBack, G.S.T] and G.S.T appears
    // exactly once past that point.
    if (hasUnresolvedTaxLabel && triple != null) {
      final netTotal = triple.netTotal;
      for (int j = trailingAmounts.length - 1; j > triple.cashBackIndex; j--) {
        final candidate = trailingAmounts[j];
        if (candidate > 0 && candidate < netTotal) {
          final count = trailingAmounts
              .where((a) => (a - candidate).abs() < 0.01)
              .length;
          if (count == 1) return candidate;
        }
      }
    }

    return null;
  }

  // ── Date ──────────────────────────────────────────────────────────────────

  static final _namedMonthFormats = [
    DateFormat('dd-MMM-yyyy'),  // 10-Jun-2026 ← FBR POS
    DateFormat('dd/MMM/yyyy'),
    DateFormat('dd MMM yyyy'),
    DateFormat('d MMM yyyy'),
    DateFormat('MMMM d, yyyy'),
    DateFormat('MMM d, yyyy'),
    DateFormat('MMM dd yyyy'),
    DateFormat('MMM dd, yyyy'),
  ];

  // Numeric-only dates (dd/MM vs MM/dd) are genuinely ambiguous when both
  // parts are <= 12, so which one to try first depends on the receipt's
  // locale. Day-first for Pakistani/FBR receipts (e.g. 01/07/2026 = 1 Jul),
  // month-first (US convention) otherwise.
  static final _dayFirstNumericFormats = [
    DateFormat('dd/MM/yyyy'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd-MM-yy'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('MM-dd-yyyy'),
    DateFormat('MM/dd/yy'),
    DateFormat('MM-dd-yy'),
  ];

  static final _monthFirstNumericFormats = [
    DateFormat('MM/dd/yyyy'),
    DateFormat('MM-dd-yyyy'),
    DateFormat('MM/dd/yy'),
    DateFormat('MM-dd-yy'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd-MM-yy'),
  ];

  // Substring match, not \b-bounded: OCR frequently mangles the leading
  // character(s), e.g. "S/NTN" reads back as "SNTN". PKR covers card
  // terminal slips ("AMOUNT PKR"), which carry no NTN/FBR text at all but
  // still use day-first dates.
  static final _pakistaniReceiptRe =
      RegExp(r'NTN|FBR|PKR', caseSensitive: false);

  static final _dateHintRe = RegExp(
    // dd-Mon-yyyy / dd/Mon/yyyy (e.g. 10-Jun-2026)
    r'(\d{1,2}[-/\s](?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)'
    r'[a-z]*[-/\s]\d{4})'
    r'|(\d{4}-\d{2}-\d{2})'
    r'|(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})'
    r'|((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?'
    r'\s+\d{1,2},?\s+\d{4})'
    r'|(\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)'
    r'[a-z]*\.?\s+\d{4})',
    caseSensitive: false,
  );

  static DateTime? _extractDate(List<String> lines) {
    final isPakistani = lines.any((l) => _pakistaniReceiptRe.hasMatch(l));
    final formats = [
      DateFormat('yyyy-MM-dd'),
      ...isPakistani ? _dayFirstNumericFormats : _monthFirstNumericFormats,
      ..._namedMonthFormats,
    ];
    for (final line in lines) {
      final match = _dateHintRe.firstMatch(line);
      if (match == null) continue;
      final candidate = match.group(0)!.trim();
      for (final fmt in formats) {
        try {
          final d = fmt.parseLoose(candidate);
          if (d.year > 2000 && d.year < 2100) return d;
        } catch (_) {}
      }
    }
    return null;
  }

  // ── Merchant ──────────────────────────────────────────────────────────────

  static final _hardSkipRe = RegExp(
    r'(\+?\d[\d\s\-().]{7,}\d)'     // phone numbers
    r'|(www\.|http|\.com|\.pk|\.net|@)'
    r'|(receipt|invoice|cashier|server|operator|terminal|'
    r'till\s*#|pos\s*#|reg\s*#|store\s*#|branch\s*#|order\s*#|'
    r'txn|transaction|bill\s*no|do\s*no|pu\s*no|ntn|nit|fbr|'
    // Metadata label-only lines
    r'date\s*:|time\s*:|date:|time:|sr\.?\s*description|'
    r'price\s+qty|qty\s+gst|no\s*of\s*item)'
    r'|(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})'   // dates
    r'|(\d{1,2}:\d{2})',                          // times
    caseSensitive: false,
  );

  static final _addressRe = RegExp(
    r'\b('
    r'shop\s*(no\.?|#)\s*\d|plot\s*(no\.?|#)|house\s*(no\.?|#)'
    r'|flat\s*(no\.?|#)|floor\s*\d'
    r'|village|housing\s*scheme|scheme'
    r'|karachi|lahore|islamabad|rawalpindi|peshawar|quetta|faisalabad'
    r'|hyderabad|liyderabad'
    r'|bahria\s*town|dha\s*(phase|karachi|lahore)'
    r'|clifton|defence\s*(phase|housing)|cantt\b|cantonment'
    r')\b',
    caseSensitive: false,
  );

  static bool _isDecorativeBanner(String line) {
    final symbolCount = RegExp(r'[*=~_\-#]').allMatches(line).length;
    return symbolCount >= 3 && symbolCount / line.length > 0.2;
  }

  static String _collapseLetterSpacing(String line) {
    final tokens = line.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.length < 4) return line;
    final ratio = tokens.where((t) => t.length == 1).length / tokens.length;
    if (ratio < 0.6) return line;
    return line
        .split(RegExp(r' {2,}'))
        .map((w) => w.replaceAll(' ', ''))
        .join(' ');
  }

  // Strips an explicit label prefix ("Business Name:", "Store Name:", …) so
  // the label text itself never ends up as part of the merchant name.
  // "na\w*" (rather than a literal "name") tolerates OCR misreads of the
  // word itself — "Business Nane:", "Business Nanie:" — which are common
  // enough on real device scans that an exact-spelling match misses them.
  // The separator class allows '2' because a real device scan produced
  // "Business Nane2AR TEX" — the ":Z" of "Name:ZAR" merged into a single
  // '2' glyph. \w{0,3} (bounded, backtrackable) covers misspelled label
  // tails ("Nane", "Nanie") without letting the label eat into the name.
  static final _merchantLabelRe = RegExp(
    r'^((?:business|store|shop|merchant)\s*na\w{0,3}\s*[:\-2]|merchant\s*[:\-])\s*',
    caseSensitive: false,
  );

  // Business-type words that print as their own OCR line right after the
  // store name/logo — "MARHABA" then "SUPERMARKET" on the next line, OCR
  // letter-spacing and all ("S UPERMARKET"). These aren't a separate
  // merchant candidate; they're the second half of the same name and get
  // appended to whichever line wins scoring, not scored independently.
  static const _businessSuffixWords = {
    'supermarket', 'store', 'mart', 'traders', 'enterprises',
    'generalstore', 'departmentalstore', 'tradingco', 'superstore',
  };

  static bool _isBusinessSuffixLine(String rawLine) =>
      _businessSuffixWords.contains(rawLine.replaceAll(' ', '').toLowerCase());

  static String? _extractMerchant(List<String> lines) {
    String? best;
    int bestScore = -999;
    int bestIndex = -1;

    for (int i = 0; i < lines.length && i < 12; i++) {
      final rawLine = lines[i];
      if (rawLine.length < 3) continue;
      if (_isDecorativeBanner(rawLine)) continue;

      var line = _collapseLetterSpacing(rawLine);
      final beforeLabelStrip = line;
      line = line.replaceFirst(_merchantLabelRe, '');
      final hadExplicitLabel = line != beforeLabelStrip;
      if (_hardSkipRe.hasMatch(line)) continue;
      if (_addressRe.hasMatch(line)) continue;
      if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(line)) continue;

      // Single leading OCR-noise character glued onto an otherwise-legible
      // logo line — real device scans produced "3MARHABALO)" and
      // "1MARHABAOIO" for the same physical MARHABA logo. Stripped before
      // scoring so one stray artifact doesn't cost the true logo line the
      // letter ratio AND the uppercase-start bonus at once (that combined
      // penalty is exactly how a garbled-but-clean "SUEERE" fragment on
      // line 1 once outscored the real brand on line 0). Requires 4+
      // letters immediately after the stray char, so "3M Store" or
      // "7-Eleven" style names that legitimately start with a digit are
      // never touched.
      final noiseStrip = RegExp(r'^[^a-zA-Z\s]([a-zA-Z]{4,}.*)$').firstMatch(line);
      if (noiseStrip != null) line = noiseStrip.group(1)!;

      // Receipt-metadata fragments that ML Kit sometimes merges onto the
      // logo's visual row (seen on a real scan: "SARHABALOLO Sale Re") —
      // strip from the tail so they don't pollute the merchant text, while
      // identical text elsewhere (a standalone "Sale Receipt" line) is
      // already rejected by _hardSkipRe above.
      line = line
          .replaceFirst(
              RegExp(
                  r'\s+(sale\s*re\w*|receipt|original|estimated\s*bill|'
                  r'bill\s*no\b.*|do\s*no\b.*|dine\s*in)\s*$',
                  caseSensitive: false),
              '')
          .trim();
      if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(line)) continue;

      int score = 0;
      final letterCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
      final digitCount = RegExp(r'\d').allMatches(line).length;
      score += ((letterCount / line.length) * 20).round();
      // An explicit "Business Name:"-style label is the receipt itself
      // telling us the merchant — trust it over generic scoring heuristics
      // (position, letter ratio) regardless of how far down the receipt or
      // how OCR-noisy everything else around it is.
      if (hadExplicitLabel) score += 30;
      // Weighted enough that an earlier line beats a later one on a small
      // letter-ratio/length edge alone — important for logos/business names
      // that OCR splits across two lines (e.g. a stylized "MARHABA" line
      // then a separate "SUPERMARKET" fragment further down): the fragment
      // closer to the top of the receipt is far more likely to be the real
      // start of the business name. Deliberately NOT weighted higher than
      // this (a *8 variant shipped briefly in build 22 and made real scans
      // worse): position is a prior, not proof — when line 0 genuinely is
      // garbage, a heavier weight makes that garbage unbeatable.
      score -= i * 3;
      score -= digitCount * 3;
      if (RegExp(r'^[A-Z]').hasMatch(line)) score += 4;
      if (line.length < 5) score -= 8;
      // Penalise single-word lines ending with colon (metadata keys).
      if (RegExp(r'^\w+:$').hasMatch(line)) score -= 12;
      // Penalise lines that look like item/product descriptions
      // (contain barcode-like digit sequences).
      if (RegExp(r'\d{5,}').hasMatch(line)) score -= 10;

      if (score > bestScore) {
        bestScore = score;
        best = line;
        bestIndex = i;
      }
    }

    if (best != null && bestIndex + 1 < lines.length) {
      final suffixLine = lines[bestIndex + 1];
      if (_isBusinessSuffixLine(suffixLine)) {
        best = '$best ${suffixLine.replaceAll(' ', '')}';
      }
    }

    return best != null ? _toTitleCase(best) : null;
  }

  // Capitalizes the first LETTER of each word, not blindly index 0 — a
  // word starting with a leading OCR-noise character ("3marhabalo)")
  // otherwise never gets title-cased at all, since index 0 is a digit
  // with no case to change and everything after it gets lowercased.
  static String _toTitleCase(String s) => s.split(' ').map((w) {
        if (w.isEmpty) return w;
        final idx = w.indexOf(RegExp(r'[a-zA-Z]'));
        if (idx == -1) return w;
        return w.substring(0, idx) +
            w[idx].toUpperCase() +
            w.substring(idx + 1).toLowerCase();
      }).join(' ');
}
