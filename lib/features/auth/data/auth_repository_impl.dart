import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  static const _networkTimeout = Duration(seconds: 10);

  final SupabaseClient _client;
  static const _googleWebClientId =
      '53257543988-5rj8taq6sdct1npmk9lde696n89s2k67.apps.googleusercontent.com';

  @override
  Stream<UserProfile?> get authStateChanges =>
      _client.auth.onAuthStateChange.asyncMap((event) async {
        final user = event.session?.user;
        if (user == null) return null;
        // Never let a slow/unreachable network strand the UI on a loading
        // spinner forever — fall back to a minimal profile built from the
        // session itself if the profiles-table fetch can't complete in time.
        try {
          return await _fetchProfile(user).timeout(_networkTimeout);
        } catch (e) {
          debugPrint('[AuthRepository] profile fetch failed, using minimal '
              'profile from session: $e');
          return _minimalProfile(user);
        }
      });

  @override
  UserProfile? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _minimalProfile(user);
  }

  @override
  Future<UserProfile> signUpWithEmail(
      String email, String password, String name) async {
    await _checkEmailRateLimit(email,
        tooManyMessage: 'Too many sign-up emails requested for this '
            'address. Please wait $_rateLimitWindowMinutes minutes and '
            'try again.');
    final res = await _client.auth
        .signUp(
          email: email,
          password: password,
          data: {'full_name': name},
          emailRedirectTo: SupabaseConfig.redirectUrl,
        )
        .timeout(_networkTimeout);
    final user = res.user;
    // With "Confirm email" enabled (this project's setting — confirmed by
    // the fact users do receive a confirmation email), `signUp()` still
    // returns a real, non-null `user` immediately (the auth.users row is
    // created right away), but `session` stays null until the email is
    // confirmed — no JWT is issued yet. The old `user == null` check never
    // matched that shape, so this fell through to the upsert below with no
    // active session, which RLS then rejected (`auth.uid()` resolves to
    // null with no session), throwing an opaque error the signup screen
    // could only show as "something went wrong" — even though the account
    // itself (and the confirmation email) had already been created.
    if (user == null || res.session == null) {
      // Supabase deliberately obfuscates signUp() when the email already
      // belongs to an existing account (e.g. one created via Google/Apple
      // sign-in) — to avoid letting an attacker probe which emails are
      // registered, it returns the same shape as a genuine new signup (a
      // non-null user, no session) rather than a clear error, and sends no
      // confirmation email at all. The one reliable signal that tells the
      // two apart is `identities`: a real new signup gets one identity
      // (the email/password identity just created) even before it's
      // confirmed, while the obfuscated case returns none, since no new
      // identity was actually created. Without this check, someone who
      // signed up via Google/Apple and later tries email/password with the
      // same address would see "Check your email" and wait forever for a
      // confirmation email Supabase never sends.
      if (user != null && (user.identities?.isEmpty ?? true)) {
        throw Exception('An account already exists for $email. Try signing '
            'in instead — if you originally signed up with Google or '
            'Apple, use that option.');
      }
      // handle_new_user() (schema.sql) already creates the profiles row
      // with the name from raw_user_meta_data, triggered by the auth.users
      // insert above — no upsert needed here, and one would fail RLS
      // anyway with no session to authenticate it.
      throw Exception(
          'Account created! Check your email ($email) to confirm before signing in.');
    }
    // Upsert profile (trigger may already have created the row).
    await _client.from('profiles').upsert({
      'id': user.id,
      'name': name,
    }).timeout(_networkTimeout);
    return _fetchProfile(user).timeout(_networkTimeout, onTimeout: () => _minimalProfile(user));
  }

  @override
  Future<UserProfile> signInWithEmail(String email, String password) async {
    final res = await _client.auth
        .signInWithPassword(email: email, password: password)
        .timeout(_networkTimeout);
    final user = res.user!;
    return _fetchProfile(user).timeout(_networkTimeout, onTimeout: () => _minimalProfile(user));
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    // Google's native iOS SDK always embeds its own nonce in the id_token
    // it issues, regardless of whether one was requested — unlike Android,
    // which only does this when asked. Supabase rejects an id_token whose
    // nonce claim doesn't match what we tell it to expect, so (like Apple,
    // below) we generate our own, hand its hash to Google, and hand the
    // raw value to Supabase for comparison.
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: _googleWebClientId,
      nonce: hashedNonce,
    );

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Google sign-in cancelled');
      }
      rethrow;
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in failed: no ID token returned');
    }
    final res = await _client.auth
        .signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          nonce: rawNonce,
        )
        .timeout(_networkTimeout);
    final user = res.user!;
    final profile = await _fetchProfile(user)
        .timeout(_networkTimeout, onTimeout: () => _minimalProfile(user));

    // Unlike Apple (handled below), Google returns its displayName on
    // every sign-in, not just the first — but handle_new_user() (schema.sql)
    // only seeds profiles.name from raw_user_meta_data->>'full_name', a key
    // the native id-token grant doesn't reliably populate for Google. Left
    // unhandled, that's a permanently empty name for every Google sign-in
    // despite Google always supplying one. Only fills a still-empty name —
    // never clobbers one the user has since edited.
    final displayName = googleUser.displayName;
    if ((profile.name?.isEmpty ?? true) && (displayName?.isNotEmpty ?? false)) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'name': displayName,
      }).timeout(_networkTimeout);
      return profile.copyWith(name: displayName);
    }
    return profile;
  }

  @override
  Future<UserProfile> signInWithApple() async {
    // Apple requires a nonce to prevent replay attacks: the raw value goes
    // to Supabase for verification, while Apple only ever sees its SHA-256
    // hash (it echoes the hash back inside the signed identityToken, which
    // Supabase checks against the raw nonce we send it).
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('Apple sign-in failed: no identity token returned');

    final res = await _client.auth
        .signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        )
        .timeout(_networkTimeout);
    final user = res.user!;

    // Apple only ever provides the user's name on the very first
    // authorization — every later sign-in omits it entirely, so this is
    // the one chance to persist it. Skipped silently if both parts are
    // empty (user declined to share it, or this isn't the first sign-in).
    final fullName = [credential.givenName, credential.familyName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    if (fullName.isNotEmpty) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'name': fullName,
      }).timeout(_networkTimeout);
    }

    return _fetchProfile(user).timeout(_networkTimeout, onTimeout: () => _minimalProfile(user));
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  @override
  Future<void> signOut() async {
    // Best-effort and non-blocking: every other network call in this file
    // is guarded by _networkTimeout, but this one wasn't — leaving it as
    // the one await with no way out if the native Google sign-out call
    // ever stalls (e.g. no Google session to tear down in the first
    // place). It's irrelevant for anyone who signed in via email or Apple,
    // so a failure or timeout here must never block the actual sign-out
    // below.
    try {
      await GoogleSignIn.instance.signOut().timeout(_networkTimeout);
    } catch (e) {
      debugPrint('[AuthRepository] Google sign-out failed/timed out, '
          'continuing with Supabase sign-out: $e');
    }
    await _client.auth.signOut().timeout(_networkTimeout);
  }

  @override
  Future<void> updateProfile({String? name, String? currency}) async {
    final uid = _client.auth.currentUser!.id;
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
    };
    if (updates.isNotEmpty) {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', uid)
          .timeout(_networkTimeout);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _checkEmailRateLimit(email,
        tooManyMessage: 'Too many password reset emails requested for '
            'this address. Please wait $_rateLimitWindowMinutes minutes '
            'and try again.');
    await _client.auth
        .resetPasswordForEmail(email, redirectTo: SupabaseConfig.redirectUrl)
        .timeout(_networkTimeout);
  }

  // Per-email quota, checked before either signup or password-reset ever
  // reaches Supabase — see schema.sql's check_auth_email_rate_limit for
  // why this exists as well as Supabase's own project-wide cap. Kept
  // permissive: this is meant to catch runaway/abusive request loops for
  // one address, not to second-guess a normal handful of genuine retries.
  static const _rateLimitMaxPerWindow = 3;
  static const _rateLimitWindowMinutes = 15;

  Future<void> _checkEmailRateLimit(String email,
      {required String tooManyMessage}) async {
    // Degrades to "allowed" on any failure — including the SQL for this
    // RPC not having been run yet against this Supabase project — rather
    // than letting a missing/broken function block every signup and
    // password reset. Supabase's own project-wide email cap still applies
    // underneath regardless of whether this per-email check ran.
    final Map<String, dynamic> result;
    try {
      result = await _client
          .rpc('check_auth_email_rate_limit', params: {
            'p_email': email,
            'p_max_per_window': _rateLimitMaxPerWindow,
            'p_window_minutes': _rateLimitWindowMinutes,
          })
          .timeout(_networkTimeout) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AuthRepository] email rate-limit check failed, '
          'allowing the request through: $e');
      return;
    }
    if (result['allowed'] != true) {
      throw Exception(tooManyMessage);
    }
  }

  Future<UserProfile> _fetchProfile(User user) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      name: data?['name'] as String?,
      avatarUrl: data?['avatar_url'] as String?,
      currency: data?['currency'] as String? ?? 'USD',
      onboardingDone: data?['onboarding_done'] as bool? ?? false,
    );
  }

  UserProfile _minimalProfile(User user) => UserProfile(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['full_name'] as String?,
      );
}
