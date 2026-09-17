import 'package:in_app_review/in_app_review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Triggers the native Play/App Store in-app review prompt exactly once,
/// after the user's 3rd successfully-kept receipt scan — the app's
/// signature feature, by which point they've had a real "this works"
/// moment.
///
/// The lifetime scan count and the "have we already asked" flag both live
/// server-side (increment_lifetime_scan_count RPC, profiles table) rather
/// than in local storage — a local-only counter resets on reinstall and
/// is inconsistent across a user's devices, which could either double-
/// prompt them or never reach the threshold at all on any single device.
/// The RPC increments and checks the threshold atomically, so two devices
/// racing to report the "3rd" scan can't both get told to prompt.
///
/// Neither Google nor Apple report back whether the user actually rated,
/// dismissed, or ignored the prompt itself (by design, to prevent apps
/// from gating features on it or nagging after a decline) — so there is
/// no "ask again later" path here regardless of storage location.
class ReviewPrompt {
  ReviewPrompt._();

  static const _triggerAtScan = 3;

  static Future<void> onSuccessfulScan() async {
    final response = await Supabase.instance.client.rpc(
      'increment_lifetime_scan_count',
      params: {'p_threshold': _triggerAtScan},
    ) as Map<String, dynamic>;

    if (response['shouldPrompt'] != true) return;

    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    }
  }
}
