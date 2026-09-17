import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository) {
    _sub = _repository.authStateChanges.listen(
      (profile) {
        _profile = profile;
        _status = profile != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
        _error = null;
        if (profile != null) {
          // Categories are scoped per-user (see ensureDefaultCategoriesForUser)
          // but this is the only place that actually knows who just signed
          // in — without this call, a user whose local DB has no rows for
          // their user_id yet (a fresh install, or an existing DB from a
          // different account on this device) sees an empty, effectively
          // unusable category dropdown everywhere one appears. No-ops
          // instantly if they already have categories, so this is safe to
          // run on every auth state change, not just first-ever sign-in.
          unawaited(DatabaseHelper.instance
              .ensureDefaultCategoriesForUser(profile.id));
        }
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[AuthProvider] stream error: $e');
        _status = AuthStatus.unauthenticated;
        _error = _friendly(e);
        notifyListeners();
      },
    );
  }

  final AuthRepository _repository;
  StreamSubscription<UserProfile?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _profile;
  bool _loading = false;
  String? _error;

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> signUp(String email, String password, String name) =>
      _run(() => _repository.signUpWithEmail(email, password, name));

  Future<void> signIn(String email, String password) =>
      _run(() => _repository.signInWithEmail(email, password));

  Future<void> signInWithGoogle() =>
      _run(() => _repository.signInWithGoogle());

  Future<void> signInWithApple() =>
      _run(() => _repository.signInWithApple());

  Future<void> signOut() => _run(() async {
        await _repository.signOut();
        _profile = null;
        _status = AuthStatus.unauthenticated;
      });

  Future<void> updateProfile({String? name, String? currency}) =>
      _run(() async {
        await _repository.updateProfile(name: name, currency: currency);
        if (_profile != null) {
          _profile = _profile!.copyWith(name: name, currency: currency);
        }
      });

  Future<void> sendPasswordReset(String email) =>
      _run(() => _repository.sendPasswordReset(email));

  /// Lets a screen consume a one-shot message (e.g. signup's "check your
  /// email" confirmation, shown as a popup) without it also lingering as an
  /// inline banner underneath — signUpWithEmail deliberately throws that
  /// message through the same `error` field a real failure would use, so
  /// the screen needs a way to clear it once it's been shown.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() fn) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Every distinct failure this app's auth flows can realistically hit
  /// gets its own message here — no case should be able to fall through to
  /// "Something went wrong" and look identical to every other failure,
  /// which is exactly what let a genuinely successful signup (build 24)
  /// look like a crash.
  ///
  /// Prefers Supabase's structured [AuthException.code] over string-
  /// matching [Object.toString] wherever possible — codes are a stable,
  /// documented contract (https://supabase.com/docs/guides/auth/debugging/error-codes),
  /// while message text can change between SDK versions and silently stop
  /// matching a `raw.contains(...)` check with no compile-time warning.
  /// String matching is still used for exceptions this app throws itself
  /// (rate-limit / pending-confirmation) and for plain Dart exceptions
  /// (timeouts, sockets) that don't carry a code at all.
  String _friendly(Object error) {
    debugPrint('[AuthProvider] error: $error');

    if (error is AuthException) {
      final byCode = _friendlyForCode(error.code);
      if (byCode != null) return byCode;
      // No mapped code (or code was null, e.g. a pre-response failure) —
      // fall through to the message-based checks below using the same
      // raw text the old implementation matched against.
    }

    // The Apple sign-in sheet uses American spelling ("canceled", one L),
    // which the generic `raw.contains('cancelled')` check below never
    // matches — without this it fell through all the way to "Something
    // went wrong", the exact class of bug already fixed once for Google's
    // "cancelled" case.
    if (error is SignInWithAppleAuthorizationException &&
        error.code == AuthorizationErrorCode.canceled) {
      return 'Sign-in was cancelled.';
    }

    final raw = error.toString();

    // Not actually an error — signUpWithEmail throws this deliberately to
    // short-circuit _run() and surface the "check your email" state
    // through the same `error` field the UI already watches.
    // signup_screen.dart's _StatusBanner renders this specific text in
    // green (it checks for "Check your email"), so passing it through
    // verbatim is the whole fix, no UI change needed.
    if (raw.contains('Check your email')) {
      return raw.replaceFirst('Exception: ', '');
    }
    // Supabase's own anti-enumeration obfuscation for signUp() against an
    // email that already has an account (see AuthRepositoryImpl's
    // identities-emptiness check) — thrown as a plain Exception, not an
    // AuthException, so it has to be matched by message text here just
    // like the "Check your email" case above, rather than by code.
    if (raw.contains('An account already exists for')) {
      return raw.replaceFirst('Exception: ', '');
    }
    // This app's own per-email rate limiter (see AuthRepositoryImpl) —
    // thrown before Supabase is even called, so it never carries an
    // AuthException code.
    if (raw.contains('Too many sign-up') || raw.contains('Too many password reset')) {
      return raw.replaceFirst('Exception: ', '');
    }
    if (raw.contains('Invalid login credentials')) return 'Incorrect email or password.';
    if (raw.contains('User already registered')) return 'An account with this email already exists.';
    if (raw.contains('Email not confirmed')) return 'Please confirm your email before signing in.';
    if (raw.contains('cancelled')) return 'Sign-in was cancelled.';
    if (raw.contains('TimeoutException')) {
      return 'The connection timed out. Check your internet and try again.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) return 'No internet connection.';
    if (raw.contains('does not exist') || raw.contains('relation')) {
      return 'Database not set up. Please run the schema SQL in your Supabase dashboard.';
    }
    // Show raw error in debug so it's easy to diagnose
    if (kDebugMode) return raw;
    return 'Something went wrong. Please try again.';
  }

  /// Maps a Supabase Auth error code to specific, accurate user-facing
  /// text. Only covers codes this app's flows (email/password + Google
  /// sign-in, no phone/SAML/MFA) can actually produce — see the full list
  /// at https://supabase.com/docs/guides/auth/debugging/error-codes.
  /// Returns null for anything unmapped so the caller falls back to
  /// message-based matching rather than silently mis-describing an error
  /// this list hasn't been taught about yet.
  String? _friendlyForCode(String? code) {
    switch (code) {
      case 'email_exists':
      case 'user_already_exists':
        return 'An account with this email already exists.';
      case 'weak_password':
        return 'That password is too weak — try a longer one with a mix '
            'of letters and numbers.';
      case 'over_email_send_rate_limit':
        // Supabase's own project-wide email cap (2/hour on the built-in
        // mailer; higher but still capped on this project's custom SMTP).
        // The app's own per-email limiter in AuthRepositoryImpl should
        // catch almost all real cases before this ever fires — reaching
        // this specific code means the *shared* project quota is
        // exhausted (e.g. many different users signing up at once), not
        // this one address being over its own limit.
        return 'Too many emails have been sent from this app recently. '
            'Please wait a while before trying again.';
      case 'over_request_rate_limit':
      case 'over_sms_send_rate_limit':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'email_not_confirmed':
        return 'Please confirm your email before signing in.';
      case 'signup_disabled':
      case 'email_provider_disabled':
        return 'New sign-ups are temporarily unavailable. Please try '
            'again later.';
      case 'user_banned':
        return 'This account has been suspended.';
      case 'validation_failed':
      case 'bad_json':
        return 'Please double-check your email address and try again.';
      case 'captcha_failed':
        return 'Verification failed. Please try again.';
      case 'session_not_found':
      case 'bad_jwt':
        return 'Your session has expired. Please sign in again.';
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
