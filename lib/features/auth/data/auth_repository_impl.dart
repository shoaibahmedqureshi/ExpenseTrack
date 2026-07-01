import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  static const _networkTimeout = Duration(seconds: 10);

  final SupabaseClient _client;
  final _googleSignIn = GoogleSignIn(
    serverClientId:
        '53257543988-5rj8taq6sdct1npmk9lde696n89s2k67.apps.googleusercontent.com',
  );

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
    final res = await _client.auth
        .signUp(
          email: email,
          password: password,
          data: {'full_name': name},
          emailRedirectTo: SupabaseConfig.redirectUrl,
        )
        .timeout(_networkTimeout);
    final user = res.user;
    if (user == null) {
      // Email confirmation is enabled — account created, awaiting confirmation.
      throw Exception(
          'Account created! Check your email ($email) to confirm before signing in.');
    }
    // Upsert profile (trigger may already have created the row).
    await _client.from('profiles').upsert({
      'id': user.id,
      'name': name,
      'email': email,
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
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final auth = await googleUser.authentication;
    final res = await _client.auth
        .signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: auth.idToken!,
          accessToken: auth.accessToken,
        )
        .timeout(_networkTimeout);
    final user = res.user!;
    return _fetchProfile(user).timeout(_networkTimeout, onTimeout: () => _minimalProfile(user));
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
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
  Future<void> sendPasswordReset(String email) => _client.auth
      .resetPasswordForEmail(email, redirectTo: SupabaseConfig.redirectUrl)
      .timeout(_networkTimeout);

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
