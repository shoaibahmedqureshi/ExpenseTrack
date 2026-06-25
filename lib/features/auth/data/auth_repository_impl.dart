import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;
  final _googleSignIn = GoogleSignIn();

  @override
  Stream<UserProfile?> get authStateChanges =>
      _client.auth.onAuthStateChange.asyncMap((event) async {
        final user = event.session?.user;
        if (user == null) return null;
        return _fetchProfile(user);
      });

  @override
  Stream<void> get passwordRecoveryRequested => _client.auth.onAuthStateChange
      .where((event) => event.event == AuthChangeEvent.passwordRecovery);

  @override
  UserProfile? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] as String?,
    );
  }

  @override
  Future<UserProfile> signUpWithEmail(
      String email, String password, String name) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
      emailRedirectTo: SupabaseConfig.redirectUrl,
    );
    final user = res.user;
    if (user == null || res.session == null) {
      // Email confirmation is enabled — account created, awaiting confirmation.
      // The `handle_new_user` DB trigger already created the profile row;
      // there's no authenticated session yet to write with from here.
      throw Exception(
          'Account created! Check your email ($email) to confirm before signing in.');
    }
    return _fetchProfile(user);
  }

  @override
  Future<UserProfile> signInWithEmail(String email, String password) async {
    final res = await _client.auth
        .signInWithPassword(email: email, password: password);
    return _fetchProfile(res.user!);
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final auth = await googleUser.authentication;
    final res = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: auth.idToken!,
      accessToken: auth.accessToken,
    );
    return _fetchProfile(res.user!);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
  }

  @override
  Future<void> updateProfile({String? name, String? currency}) async {
    final uid = _client.auth.currentUser!.id;
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
    };
    if (updates.isNotEmpty) {
      await _client.from('profiles').update(updates).eq('id', uid);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.redirectUrl,
      );

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
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
}
