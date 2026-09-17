import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:outlay/features/auth/domain/entities/user_profile.dart';
import 'package:outlay/features/auth/domain/repositories/auth_repository.dart';
import 'package:outlay/features/auth/presentation/providers/auth_provider.dart';

/// Repository double that throws whatever [signUpError] is on signUp, so
/// each test just supplies the specific exception it wants AuthProvider's
/// error-mapping to see — real callers all go through the same _run()/
/// _friendly() path regardless of which auth method is called.
class _ThrowingAuthRepository implements AuthRepository {
  _ThrowingAuthRepository(this.signUpError);
  final Object signUpError;

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
  @override
  UserProfile? get currentUser => null;
  @override
  Future<UserProfile> signUpWithEmail(String email, String password, String name) {
    throw signUpError;
  }

  @override
  Future<UserProfile> signInWithEmail(String e, String p) async =>
      const UserProfile(id: '1', email: 'a@b.com');
  @override
  Future<UserProfile> signInWithGoogle() async =>
      const UserProfile(id: '1', email: 'a@b.com');
  @override
  Future<UserProfile> signInWithApple() async =>
      const UserProfile(id: '1', email: 'a@b.com');
  @override
  Future<void> signOut() async {}
  @override
  Future<void> updateProfile({String? name, String? currency}) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

Future<String?> _errorFor(Object thrown) async {
  final provider = AuthProvider(_ThrowingAuthRepository(thrown));
  addTearDown(provider.dispose);
  await provider.signUp('a@b.com', 'password123', 'Jane');
  return provider.error;
}

void main() {
  test(
      'CRITICAL: signUp() surfaces the real "check your email" text, not '
      'the generic "Something went wrong" fallback — real device signups '
      'showed the generic message even though the account and '
      'confirmation email had already been created', () async {
    // Exactly what AuthRepositoryImpl.signUpWithEmail throws when Supabase
    // returns a user but no session (email confirmation pending).
    final error = await _errorFor(Exception(
        'Account created! Check your email (a@b.com) to confirm before signing in.'));

    expect(error, isNotNull);
    expect(error, contains('Check your email'));
    expect(error, contains('a@b.com'));
    expect(error, isNot(contains('Something went wrong')),
        reason: 'signup_screen.dart only shows the "account created" popup '
            'when the message contains "Check your email" — swallowing '
            'it into the generic fallback makes a successful signup look '
            'like a failure.');
  });

  test(
      'CRITICAL: signing up with an email that already has a Google/Apple '
      '-linked account surfaces a "try signing in instead" message, not '
      'the generic fallback — Supabase deliberately returns the same '
      'no-session shape as a genuine new signup for this case (to avoid '
      'leaking which emails are registered), so without a specific match '
      'here the user would be told to check an email that Supabase never '
      'actually sends', () async {
    // Exactly what AuthRepositoryImpl.signUpWithEmail throws when the
    // returned user's identities list is empty (see its identities check).
    final error = await _errorFor(Exception(
        'An account already exists for a@b.com. Try signing in instead — '
        'if you originally signed up with Google or Apple, use that option.'));

    expect(error, isNotNull);
    expect(error, contains('account already exists'));
    expect(error, contains('Try signing in'));
    expect(error, isNot(contains('Check your email')),
        reason: 'this case must not trigger signup_screen.dart\'s '
            '"account created" success popup — no account was actually '
            'created by this signup attempt.');
    expect(error, isNot(contains('Something went wrong')));
  });

  test(
      'this app\'s own per-email rate limiter (AuthRepositoryImpl, checked '
      'before Supabase is even called) surfaces its specific message, not '
      'the generic fallback', () async {
    final error = await _errorFor(Exception(
        'Too many sign-up emails requested for this address. Please wait '
        '15 minutes and try again.'));

    expect(error, contains('Too many sign-up emails'));
    expect(error, isNot(contains('Something went wrong')));
  });

  test(
      'Supabase\'s own project-wide email quota (AuthException with code '
      'over_email_send_rate_limit) is mapped by error CODE, not by '
      'parsing message text that can change between SDK versions',
      () async {
    final error = await _errorFor(AuthApiException(
      'email rate limit exceeded',
      statusCode: '429',
      code: 'over_email_send_rate_limit',
    ));

    expect(error, contains('Too many emails have been sent from this app'));
    expect(error, isNot(contains('Something went wrong')));
  });

  test('weak_password code gets a specific, actionable message', () async {
    final error = await _errorFor(AuthApiException(
      'Password should be at least 6 characters',
      statusCode: '422',
      code: 'weak_password',
    ));

    expect(error, contains('too weak'));
    expect(error, isNot(contains('Something went wrong')));
  });

  test('email_exists code is distinguishable from every other failure',
      () async {
    final error = await _errorFor(AuthApiException(
      'A user with this email address has already been registered',
      statusCode: '422',
      code: 'email_exists',
    ));

    expect(error, contains('already exists'));
    expect(error, isNot(contains('Something went wrong')));
  });

  test(
      'an AuthException whose code isn\'t in the mapping falls back to '
      'message-based matching rather than mis-describing it as something '
      'it isn\'t', () async {
    final error = await _errorFor(AuthApiException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    ));

    expect(error, 'Incorrect email or password.');
  });
}
