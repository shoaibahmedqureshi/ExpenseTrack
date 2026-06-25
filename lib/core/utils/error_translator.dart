import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts raw Supabase/IO exceptions into short, user-facing messages.
String friendlyErrorMessage(Object error) {
  debugPrint('[error] $error');

  if (error is AuthException) return _authMessage(error);
  if (error is PostgrestException) return _postgrestMessage(error);
  if (error is StorageException) return _storageMessage(error);
  if (error is SocketException) return 'No internet connection. Please check your network and try again.';
  if (error is TimeoutException) return 'The request timed out. Please try again.';

  final raw = error.toString().replaceFirst('Exception: ', '');
  if (raw.contains('Check your email')) return raw;
  if (raw.contains('cancelled')) return 'Action was cancelled.';
  if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
    return 'No internet connection. Please check your network and try again.';
  }

  if (kDebugMode) return raw;
  return 'Something went wrong. Please try again.';
}

String _authMessage(AuthException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('invalid login credentials')) return 'Incorrect email or password.';
  if (msg.contains('user already registered') || msg.contains('already registered')) {
    return 'An account with this email already exists.';
  }
  if (msg.contains('email not confirmed')) return 'Please confirm your email before signing in.';
  if (msg.contains('email rate limit') || msg.contains('rate limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (msg.contains('password should be at least') || msg.contains('weak password')) {
    return 'Password is too weak. Use at least 6 characters.';
  }
  if (msg.contains('unable to validate email') || msg.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }
  if (msg.contains('signups not allowed') || msg.contains('signup is disabled')) {
    return 'New sign-ups are currently disabled.';
  }
  if (msg.contains('token has expired') || msg.contains('invalid token') || msg.contains('expired')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (msg.contains('user not found')) return 'No account found with this email.';
  if (kDebugMode) return e.message;
  return 'Something went wrong while authenticating. Please try again.';
}

String _postgrestMessage(PostgrestException e) {
  final msg = e.message.toLowerCase();
  if (e.code == '23505' || msg.contains('duplicate key')) {
    return 'This record already exists.';
  }
  if (e.code == '23503' || msg.contains('foreign key')) {
    return 'This action conflicts with related data.';
  }
  if (e.code == '42P01' || msg.contains('relation') && msg.contains('does not exist')) {
    return 'Database not set up. Please run the schema SQL in your Supabase dashboard.';
  }
  if (e.code == 'PGRST301' || msg.contains('jwt')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (msg.contains('permission denied') || msg.contains('row-level security')) {
    return 'You don\'t have permission to do that.';
  }
  if (kDebugMode) return e.message;
  return 'Something went wrong while saving your data. Please try again.';
}

String _storageMessage(StorageException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('not found')) return 'The requested file could not be found.';
  if (msg.contains('already exists')) return 'A file with that name already exists.';
  if (kDebugMode) return e.message;
  return 'Something went wrong while uploading the file. Please try again.';
}
