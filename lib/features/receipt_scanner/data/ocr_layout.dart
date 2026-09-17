/// Reconstructs natural reading order from positioned OCR line fragments.
///
/// ML Kit returns text grouped into blocks in *detection* order, not reading
/// order. On multi-column POS receipts the label column ("Net Total") and
/// the amount column ("401.00") are usually detected as separate blocks, so
/// `RecognizedText.text` interleaves whole columns instead of rows — the
/// amounts end up dozens of lines away from their labels.
///
/// This module rebuilds visual rows from the per-line bounding boxes:
/// fragments whose vertical centers overlap are the same printed row, and
/// within a row fragments read left to right. The output is what a human
/// sees: "Net Total    401.00" on one line, for any receipt layout, from
/// any POS vendor — no per-layout heuristics.
library;

/// One OCR'd text fragment with its position on the source image.
/// Pure Dart (no ML Kit / dart:ui types) so layout logic is unit-testable.
class OcrLine {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get yCenter => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Groups [lines] into visual rows and returns text in reading order
/// (top-to-bottom, left-to-right), one row per output line.
///
/// Two fragments belong to the same row when their vertical centers are
/// closer than half the smaller fragment's height — the standard row-banding
/// rule: printed characters on the same baseline overlap almost entirely,
/// while consecutive receipt rows are at least a full line-height apart.
/// Slight photo skew shifts centers by only a few pixels across the page
/// width, well inside the half-height tolerance.
String reconstructReadingOrder(List<OcrLine> lines) {
  if (lines.isEmpty) return '';

  final sorted = [...lines]..sort((a, b) => a.yCenter.compareTo(b.yCenter));

  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && _sameRow(row, line)) {
      row.add(line);
    } else {
      rows.add([line]);
    }
  }

  final buffer = StringBuffer();
  for (final row in rows) {
    row.sort((a, b) => a.left.compareTo(b.left));
    buffer.writeln(row.map((l) => l.text.trim()).join(' '));
  }
  return buffer.toString();
}

bool _sameRow(List<OcrLine> row, OcrLine line) {
  // Compare against the row's running center so a gently skewed row still
  // accumulates instead of splitting halfway.
  final rowCenter =
      row.map((l) => l.yCenter).reduce((a, b) => a + b) / row.length;
  final rowMinHeight =
      row.map((l) => l.height).reduce((a, b) => a < b ? a : b);
  final tolerance =
      0.5 * (line.height < rowMinHeight ? line.height : rowMinHeight);
  if ((line.yCenter - rowCenter).abs() > tolerance) return false;

  // The check above compares each candidate to the row's *running*
  // average center, which shifts every time a line joins — so a sequence
  // of lines each individually within tolerance of the previous accepted
  // one can walk the average arbitrarily far down the page, silently
  // stitching several real, unrelated printed rows into one (seen on a
  // real iOS scan: a table's label column and its value column, plus
  // unrelated footer text, all merged onto a single output line). A
  // genuine single printed row's fragments — however many words or
  // columns share it — all span roughly one line-height top-to-bottom
  // regardless of how many join, so cap the row's total vertical extent
  // instead of trusting the drifting center alone.
  final rowTop = row.map((l) => l.top).reduce((a, b) => a < b ? a : b);
  final rowBottom = row.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
  final span = (rowBottom > line.bottom ? rowBottom : line.bottom) -
      (rowTop < line.top ? rowTop : line.top);
  return span <= 1.5 * rowMinHeight;
}
