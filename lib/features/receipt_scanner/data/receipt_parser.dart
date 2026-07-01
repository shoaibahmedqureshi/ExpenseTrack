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
///   • Net Total = the amount just before the biggest upward jump (CashReceived).
///   • Tax = the last unique amount after CashBack in the trailing block.
class ReceiptParser {
  ReceiptParser._();

  static ReceiptScanResult parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final trailingAmounts = _extractTrailingAmountsBlock(lines);
    final netIdx = _netTotalIndexFromBlock(trailingAmounts);

    final result = ReceiptScanResult(
      rawText: rawText,
      total: _extractTotal(lines, trailingAmounts, netIdx),
      tax: _extractTax(lines, trailingAmounts, netIdx),
      date: _extractDate(lines),
      merchant: _extractMerchant(lines),
    );

    dev.log(
      'trailingBlock=$trailingAmounts netIdx=$netIdx\n'
      'merchant=${result.merchant} total=${result.total} '
      'tax=${result.tax} date=${result.date}',
      name: 'ReceiptParser',
    );
    return result;
  }

  // ── Amount regex ──────────────────────────────────────────────────────────

  // Requires two decimal places (X.XX or X,XXX.XX).
  // Deliberately excludes plain integers (barcodes, quantities) and
  // tax-rate percentages (8.25%).
  static final _amountRe = RegExp(
    r'(?:rs\.?\s*|pkr\.?\s*|inr\.?\s*|aed\.?\s*|gbp\.?\s*|£\s*|\$\s*|€\s*)?'
    r'(\d{1,3}(?:,\d{3})*\.\d{2})',
    caseSensitive: false,
  );

  static double? _largestAmountOnLine(String line) {
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
          _postTotalExclusion.hasMatch(next)) break;
    }
    return null;
  }

  static bool _isBareAmountLine(String line) {
    final stripped = line
        .replaceAll(_amountRe, '')
        .replaceAll(RegExp(r'[rs\$pkr£€]', caseSensitive: false), '')
        .trim();
    return stripped.isEmpty;
  }

  // ── Trailing amounts block ────────────────────────────────────────────────
  //
  // On split-column POS receipts ML Kit reads the rightmost "Total" column
  // last. We walk backwards from the end collecting contiguous amount lines.

  static List<double> _extractTrailingAmountsBlock(List<String> lines) {
    // Find last line that has an amount.
    int end = lines.length - 1;
    while (end >= 0 && _largestAmountOnLine(lines[end]) == null) end--;
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

  /// Index of Net Total in the trailing block using the "CashReceived jump"
  /// heuristic. CashReceived is always notably larger than Net Total
  /// (customer pays more cash than they owe), creating the biggest jump.
  /// Returns -1 if not found.
  static int _netTotalIndexFromBlock(List<double> amounts) {
    int biggestJumpIdx = -1;
    double biggestJump = 0;
    for (int i = 1; i < amounts.length; i++) {
      final jump = amounts[i] - amounts[i - 1];
      if (jump > biggestJump && jump > 50) {
        biggestJump = jump;
        biggestJumpIdx = i;
      }
    }
    return biggestJumpIdx > 0 ? biggestJumpIdx - 1 : -1;
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
  // Uses prefix patterns to tolerate OCR typos (CashRecelved, CashRecieved…).
  static final _postTotalExclusion = RegExp(
    r'\b(cash\s*rec'          // CashReceived / CashRecelved / Cash Received
    r'|cash\s*back'
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
    List<double> trailingAmounts,
    int netIdx,
  ) {
    // Strategy 1: keyword + inline/nearby amount (most receipts).
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (_postTotalExclusion.hasMatch(line)) continue;
      if (_totalKeywords.hasMatch(line)) {
        final amount = _amountNearLine(lines, i);
        if (amount != null) return amount;
      }
    }

    // Strategy 2: trailing amounts block — biggest-jump heuristic.
    // For FBR-POS split-column receipts where labels have no inline amounts.
    if (netIdx >= 0) return trailingAmounts[netIdx];

    // Strategy 3: largest amount on any non-excluded line.
    double? biggest;
    for (final line in lines) {
      if (_postTotalExclusion.hasMatch(line)) continue;
      final a = _largestAmountOnLine(line);
      if (a != null && (biggest == null || a > biggest)) biggest = a;
    }
    return biggest;
  }

  // ── Tax ───────────────────────────────────────────────────────────────────

  static final _taxKeywords = RegExp(
    r'('
    r'\btax\b|\btaxes\b|\btax\s*amount\b|\btax\s*total\b'
    r'|\bvat\b|\bv\.a\.t\.?'
    r'|\bgst\b|\bg\.s\.t\.?'
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

  // Table column header lines contain multiple column-name words.
  // "Price Qty GST Rate" → 3 column keywords → skip entirely.
  static final _columnHeaderRe = RegExp(
    r'\b(sr\.?|description|price|qty|quantity|rate|disc(?:ount)?|'
    r'total|no\.?\s*of\s*item)\b',
    caseSensitive: false,
  );

  static double? _extractTax(
    List<String> lines,
    List<double> trailingAmounts,
    int netIdx,
  ) {
    // Strategy 1: keyword + inline/nearby amount.
    final taxAmounts = <double>[];
    bool hasUnresolvedTaxLabel = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!_taxKeywords.hasMatch(line)) continue;
      if (_taxRegNoRe.hasMatch(line)) continue;
      // Skip table column headers like "Price Qty GST Rate".
      if (_columnHeaderRe.allMatches(line).length >= 2) continue;

      final amount = _amountNearLine(lines, i, lookahead: 3);
      if (amount != null) {
        taxAmounts.add(amount);
      } else {
        hasUnresolvedTaxLabel = true;
      }
    }

    if (taxAmounts.isNotEmpty) {
      return taxAmounts.reduce((a, b) => a + b);
    }

    // Strategy 2: trailing block — tax is the last unique amount after CashBack.
    // On FBR-POS receipts: [..., NetTotal, CashReceived, CashBack, G.S.T]
    // G.S.T is the last entry and appears exactly once in the block.
    if (hasUnresolvedTaxLabel &&
        netIdx >= 0 &&
        netIdx + 2 < trailingAmounts.length) {
      final netTotal = trailingAmounts[netIdx];
      final cashBackIdx = netIdx + 2;
      // Scan amounts after CashBack, pick the last one that is:
      //   (a) less than net total  (b) appears only once in the block
      for (int j = trailingAmounts.length - 1; j > cashBackIdx; j--) {
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

  static final _dateFormats = [
    DateFormat('yyyy-MM-dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('MM-dd-yyyy'),
    DateFormat('MM/dd/yy'),
    DateFormat('MM-dd-yy'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd-MM-yy'),
    DateFormat('dd-MMM-yyyy'),  // 10-Jun-2026 ← FBR POS
    DateFormat('dd/MMM/yyyy'),
    DateFormat('dd MMM yyyy'),
    DateFormat('d MMM yyyy'),
    DateFormat('MMMM d, yyyy'),
    DateFormat('MMM d, yyyy'),
    DateFormat('MMM dd yyyy'),
    DateFormat('MMM dd, yyyy'),
  ];

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
    for (final line in lines) {
      final match = _dateHintRe.firstMatch(line);
      if (match == null) continue;
      final candidate = match.group(0)!.trim();
      for (final fmt in _dateFormats) {
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

  static String? _extractMerchant(List<String> lines) {
    String? best;
    int bestScore = -999;

    for (int i = 0; i < lines.length && i < 12; i++) {
      final rawLine = lines[i];
      if (rawLine.length < 3) continue;
      if (_isDecorativeBanner(rawLine)) continue;

      final line = _collapseLetterSpacing(rawLine);
      if (_hardSkipRe.hasMatch(line)) continue;
      if (_addressRe.hasMatch(line)) continue;
      if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(line)) continue;

      int score = 0;
      final letterCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
      final digitCount = RegExp(r'\d').allMatches(line).length;
      score += ((letterCount / line.length) * 20).round();
      score -= i * 2;
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
      }
    }

    return best != null ? _toTitleCase(best) : null;
  }

  static String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
