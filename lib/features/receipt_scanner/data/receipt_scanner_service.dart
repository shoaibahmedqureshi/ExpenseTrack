import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/receipt_scan_result.dart';
import 'ocr_layout.dart';
import 'receipt_parser.dart';

enum ScanSource { camera, gallery }

class ReceiptScannerService {
  ReceiptScannerService._();
  static final instance = ReceiptScannerService._();

  final _picker = ImagePicker();
  // Latin script covers most printed receipts; swap for ChineseScript etc. if needed.
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Longest side after our own resize (see _normalizeOrientation) — dense
  // thermal-print receipts need resolution more than they need a small
  // file, ML Kit accuracy drops sharply once small digits blur. Processing
  // is on-device, so a larger image costs only a few hundred ms, not
  // bandwidth.
  static const _maxDimension = 2560;

  /// Returns null if the user cancels image selection.
  Future<ReceiptScanResult?> scan(ScanSource source) async {
    String captureDiagnostic;
    File? captured;
    if (source == ScanSource.camera) {
      // Native guided capture (ML Kit Document Scanner on Android,
      // VisionKit on iOS): live edge detection draws a frame around the
      // receipt, auto-crops with perspective correction, and offers
      // flash — the capture-quality problems (blur, partial framing,
      // sideways pixels) that survived every downstream fix simply can't
      // reach the OCR stage when the scanner won't capture until it has
      // the document properly in frame.
      (captured, captureDiagnostic) = await _scanWithDocScanner();
      // Distinguish "user cancelled" (null + cancel marker: stop quietly)
      // from "scanner unavailable/broke" (null + error text: fall back to
      // the plain camera so scanning still works at all).
      if (captured == null) {
        if (captureDiagnostic == _cancelledMarker) return null;
        final XFile? file =
            await _picker.pickImage(source: ImageSource.camera);
        if (file == null) return null;
        captured = File(file.path);
        captureDiagnostic = 'fallback plain camera ($captureDiagnostic)';
      }
    } else {
      // Gallery: no guided flow exists for already-taken photos. Note:
      // deliberately NOT passing imageQuality/maxWidth to pickImage — its
      // internal resize step is where vertical gallery photos' pixels came
      // back sideways with no EXIF tag left to correct against (confirmed
      // via build-18 diagnostics). _normalizeOrientation owns resize.
      final XFile? file =
          await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return null;
      captured = File(file.path);
      captureDiagnostic = 'gallery';
    }

    final (normalized, orientDiagnostic) =
        await _normalizeOrientation(captured);
    final (recognized, rotationDiagnostic) =
        await _recognizeWithRotationFallback(normalized);
    final normalizeDiagnostic =
        '$captureDiagnostic | $orientDiagnostic | $rotationDiagnostic';

    // RecognizedText.text lists whole blocks in detection order, which on
    // multi-column receipts splits labels and amounts into distant chunks.
    // Rebuild true reading order from the per-line bounding boxes instead,
    // so "Net Total" and its amount land on one line for the parser.
    final fragments = <OcrLine>[
      for (final block in recognized.blocks)
        for (final line in block.lines)
          OcrLine(
            text: line.text,
            left: line.boundingBox.left,
            top: line.boundingBox.top,
            right: line.boundingBox.right,
            bottom: line.boundingBox.bottom,
          ),
    ];
    final orderedText = reconstructReadingOrder(fragments);

    dev.log(
        '=== RAW OCR TEXT ===\n${recognized.text}\n'
        '=== RECONSTRUCTED ===\n$orderedText\n=== END OCR ===',
        name: 'ReceiptScanner');
    final result = ReceiptParser.parse(orderedText);
    _uploadDebugLog(result, recognized.text, fragments, normalizeDiagnostic);
    return result;
  }

  /// Sentinel diagnostic meaning the user backed out of the scanner UI —
  /// not an error, so no fallback camera and no scan result.
  static const _cancelledMarker = 'cancelled';

  /// Runs the native guided document scanner and returns the captured
  /// page's file, or null with a diagnostic explaining why (cancelled vs
  /// failed). Returned image locations are file paths on iOS but can be
  /// content:// URIs on Android (per ImageScanResult's docs), which dart:io
  /// can't open — that case degrades to the plain camera rather than
  /// crashing the scan flow, and the diagnostic will say so if it ever
  /// happens on a real device.
  Future<(File?, String)> _scanWithDocScanner() async {
    try {
      final result =
          await FlutterDocScanner().getScannedDocumentAsImages(page: 1);
      if (result == null || result.images.isEmpty) {
        return (null, _cancelledMarker);
      }
      var path = result.images.first;
      if (path.startsWith('file://')) {
        path = Uri.parse(path).toFilePath();
      } else if (path.contains('://')) {
        return (null, 'doc scanner returned non-file URI: $path');
      }
      final file = File(path);
      if (!await file.exists()) {
        return (null, 'doc scanner path does not exist: $path');
      }
      return (file, 'doc-scanner ok');
    } catch (e) {
      return (null, 'doc scanner threw: $e');
    }
  }

  /// Decodes the picked photo, bakes its EXIF orientation into the pixel
  /// data, resizes it ourselves (see `scan` for why this no longer happens
  /// inside `pickImage`), and re-encodes to a temp JPEG — that's what
  /// `InputImage.fromFile` receives, so ML Kit never has an orientation tag
  /// left to misinterpret or a plugin-internal resize step left to corrupt.
  ///
  /// Confirmed on a real device (build 18's diagnostic, before this
  /// resize-ownership change): a vertical gallery photo decoded to
  /// 2560x1920 — landscape — with baking reporting no rotation applied,
  /// meaning the pixels were already sideways with no EXIF tag to fix
  /// against. That ruled out the original HEIC-misdecode theory (the file
  /// was a normal jpg) and pointed at image_picker's own `maxWidth`/
  /// `imageQuality` resize path as the thing actually introducing the
  /// rotation, not this function.
  ///
  /// Returns the diagnostic string alongside the file (rather than just
  /// logging it) so it reaches `ocr_debug_logs` for the next real scan.
  Future<(File, String)> _normalizeOrientation(File original) async {
    final ext = original.path.contains('.')
        ? original.path.split('.').last.toLowerCase()
        : '(none)';
    try {
      final bytes = await original.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return (original, 'decode returned null, ext=$ext bytes=${bytes.length}');
      }
      // A real receipt photo is at minimum a few hundred pixels per side.
      // Anything smaller signals decodeImage misread an unsupported
      // container as a different format and produced garbage rather than
      // failing cleanly — using that would feed ML Kit noise, not a photo.
      if (decoded.width < 200 || decoded.height < 200) {
        return (
          original,
          'decoded implausibly small ${decoded.width}x${decoded.height}, '
              'ext=$ext — used original instead'
        );
      }
      final oriented = img.bakeOrientation(decoded);

      final longSide =
          oriented.width > oriented.height ? oriented.width : oriented.height;
      final resized = longSide > _maxDimension
          ? (oriented.width > oriented.height
              ? img.copyResize(oriented,
                  width: _maxDimension,
                  interpolation: img.Interpolation.linear)
              : img.copyResize(oriented,
                  height: _maxDimension,
                  interpolation: img.Interpolation.linear))
          : oriented;

      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/'
          'receipt_scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(resized, quality: 92));
      return (
        outFile,
        'ok: ext=$ext decoded=${decoded.width}x${decoded.height} '
            'baked=${oriented.width}x${oriented.height} '
            'resized=${resized.width}x${resized.height}'
      );
    } catch (e) {
      dev.log('orientation normalization failed, using original: $e',
          name: 'ReceiptScanner');
      return (original, 'exception: $e, ext=$ext');
    }
  }

  // A real receipt yields hundreds of characters; a genuinely sideways
  // image yields near-nothing (real device scans came back with 0-2 stray
  // characters — "8", "N", "KZ"). Anything under this is worth a retry
  // rather than trusting it's just a short receipt.
  static const _sparseTextThreshold = 20;

  /// Runs text recognition on [file], and if the result looks sparse,
  /// retries at 90°/180°/270° and keeps whichever rotation produced the
  /// most text. `InputImage.fromFile` trusts EXIF for orientation, but a
  /// gallery photo taken with the phone held sideways has *correct* EXIF
  /// for how the phone was held — there's no tag anywhere indicating the
  /// receipt itself is rotated within that frame, unlike the orientation
  /// bug `_normalizeOrientation` fixes. The guided doc-scanner path (camera
  /// source) shouldn't usually need this — it only fires when a result is
  /// actually sparse — but gallery photos have no live framing guidance at
  /// all, so this is the safety net for whatever orientation the user
  /// happened to hold the phone in when the original photo was taken.
  Future<(RecognizedText, String)> _recognizeWithRotationFallback(
      File file) async {
    final first = await _recognizer.processImage(InputImage.fromFile(file));
    if (first.text.trim().length >= _sparseTextThreshold) {
      return (first, 'rotation=0 (ok, ${first.text.trim().length} chars)');
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(await file.readAsBytes());
    } catch (e) {
      return (first, 'rotation=0 (sparse, retry decode failed: $e)');
    }
    if (decoded == null) {
      return (first, 'rotation=0 (sparse, retry decode returned null)');
    }

    var best = first;
    var bestAngle = 0;
    final tempDir = await getTemporaryDirectory();
    for (final angle in [90, 180, 270]) {
      try {
        final rotated = img.copyRotate(decoded, angle: angle);
        final rotatedFile = File('${tempDir.path}/'
            'receipt_scan_rot${angle}_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await rotatedFile.writeAsBytes(img.encodeJpg(rotated, quality: 92));
        final attempt = await _recognizer
            .processImage(InputImage.fromFile(rotatedFile));
        if (attempt.text.trim().length > best.text.trim().length) {
          best = attempt;
          bestAngle = angle;
        }
      } catch (e) {
        dev.log('rotation fallback at $angle° failed: $e',
            name: 'ReceiptScanner');
      }
    }
    return (
      best,
      'rotation=$bestAngle (sparse first attempt, '
          '${first.text.trim().length}→${best.text.trim().length} chars)'
    );
  }

  /// Separates the parser's input from the appended detection-order dump in
  /// an uploaded raw_text. Anything after this line is diagnostic only —
  /// strip it before re-running a stored scan through ReceiptParser.
  static const detectionOrderMarker =
      '=== DETECTION-ORDER OCR (diagnostic, not parser input) ===';

  /// Marks the start of per-fragment bounding-box data in an uploaded
  /// raw_text — one `text  |  top,bottom,left,right` per line, in the same
  /// order `reconstructReadingOrder` received them (yCenter-sorted). Lets a
  /// scrambled reconstruction be replayed exactly against real coordinates
  /// instead of guessed at, since ML Kit's row/column detection can differ
  /// between Android and iOS in ways plain text alone doesn't reveal.
  static const geometryMarker =
      '=== FRAGMENT GEOMETRY top,bottom,left,right (diagnostic) ===';

  /// Marks the start of the orientation-normalization diagnostic (decode
  /// success/failure, dimensions, file extension) in an uploaded raw_text.
  static const normalizeMarker =
      '=== ORIENTATION NORMALIZATION (diagnostic) ===';

  /// Emails whose scans upload debug logs even in release/TestFlight builds.
  /// iOS ML Kit is a different recognition model than Android's, so real
  /// iPhone scans can only be diagnosed if TestFlight uploads them — but
  /// public users' receipts must never upload silently, hence the
  /// allowlist rather than dropping the kDebugMode gate entirely.
  static const _testerEmails = {
    '08bitsaqureshi@seecs.edu.pk',
    'shoaibq.abcd@gmail.com',
  };

  /// Shoaib's Supabase auth uid (source of every existing ocr_debug_logs
  /// row) — covers the case where the app account's email isn't in the
  /// list above.
  static const _testerUids = {
    '1432aac1-8b1c-4742-9529-ad12f5e3274e',
  };

  /// Testing-only: ships raw OCR text + parsed fields to Supabase so scans
  /// on a physical device can be reviewed without a live adb connection.
  /// Runs in debug builds, and in release builds only for tester accounts.
  void _uploadDebugLog(ReceiptScanResult result, String detectionOrderText,
      List<OcrLine> fragments, String normalizeDiagnostic) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final isTester =
        _testerEmails.contains(user.email?.trim().toLowerCase() ?? '') ||
            _testerUids.contains(user.id);
    if (!kDebugMode && !isTester) return;
    final sortedFragments = [...fragments]
      ..sort((a, b) => a.yCenter.compareTo(b.yCenter));
    final geometryText = sortedFragments
        .map((f) =>
            '${f.text}  |  ${f.top.toStringAsFixed(1)},${f.bottom.toStringAsFixed(1)},'
            '${f.left.toStringAsFixed(1)},${f.right.toStringAsFixed(1)}')
        .join('\n');
    Supabase.instance.client.from('ocr_debug_logs').insert({
      'user_id': user.id,
      'raw_text': '${result.rawText}\n$detectionOrderMarker\n'
          '$detectionOrderText\n$geometryMarker\n$geometryText\n'
          '$normalizeMarker\n$normalizeDiagnostic',
      'merchant': result.merchant,
      'total': result.total,
      'tax': result.tax,
      'scan_date': result.date?.toIso8601String(),
    }).catchError((e) {
      dev.log('debug log upload failed: $e', name: 'ReceiptScanner');
    });
  }

  void dispose() => _recognizer.close();
}
