import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/core/constants/app_constants.dart';

void main() {
  test('the version shown in the app matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final value = line.split(':')[1].trim(); // 1.2.0+52
    final parts = value.split('+');
    expect(AppConstants.appVersion, parts[0]);
    expect(AppConstants.appBuild, int.parse(parts[1]));
    expect(AppConstants.versionLabel, '${parts[0]} (${parts[1]})');
  });
}
