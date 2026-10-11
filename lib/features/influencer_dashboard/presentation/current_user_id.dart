import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in user's id, or '' when nobody is signed in or Supabase is not initialised.
String currentUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id ?? '';
  } catch (_) {
    return '';
  }
}
