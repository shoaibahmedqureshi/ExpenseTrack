import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// A short, random, persistent-per-install identifier — not a UUID
/// package, just enough to tell two physical devices' debug log rows
/// apart. Generated once and cached in SharedPreferences; every debug
/// snapshot upload (sync_debug_logs, budget_debug_logs) tags itself with
/// this so cross-device investigations can actually attribute each row to
/// a device instead of guessing whether two snapshots are the same
/// device's state changing over time or two different devices' states
/// interleaved.
class DeviceDebugId {
  DeviceDebugId._();

  static const _prefKey = 'device_debug_id';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefKey);
    if (id == null) {
      final rand = Random();
      id = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
          '-${rand.nextInt(0xFFFFFF).toRadixString(36)}';
      await prefs.setString(_prefKey, id);
    }
    _cached = id;
    return id;
  }
}
