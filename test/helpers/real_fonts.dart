import 'dart:io';

import 'package:flutter/services.dart';

/// Flutter tests render every glyph as a full-width square by default, which makes text look
/// far wider than it is on a device and produces false overflow failures. Loading the real
/// Roboto from the Flutter SDK gives realistic text widths for layout tests.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ]) {
    final file = File('$dir/$f');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
  }
  await loader.load();
}
