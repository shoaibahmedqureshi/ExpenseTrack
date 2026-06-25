import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/error_translator.dart';
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
        notifyListeners();
      },
      onError: (e) {
        _status = AuthStatus.unauthenticated;
        _error = friendlyErrorMessage(e);
        notifyListeners();
      },
    );
    _recoverySub = _repository.passwordRecoveryRequested.listen((_) {
      _isPasswordRecovery = true;
      notifyListeners();
    });
  }

  final AuthRepository _repository;
  StreamSubscription<UserProfile?>? _sub;
  StreamSubscription<void>? _recoverySub;

  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _profile;
  bool _loading = false;
  String? _error;
  bool _isPasswordRecovery = false;

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// True once a password-recovery deep link has been processed; the UI
  /// should show the set-new-password screen instead of routing normally.
  bool get isPasswordRecovery => _isPasswordRecovery;

  Future<void> updatePassword(String newPassword) => _run(() async {
        await _repository.updatePassword(newPassword);
        _isPasswordRecovery = false;
      });

  Future<void> signUp(String email, String password, String name) =>
      _run(() => _repository.signUpWithEmail(email, password, name));

  Future<void> signIn(String email, String password) =>
      _run(() => _repository.signInWithEmail(email, password));

  Future<void> signInWithGoogle() =>
      _run(() => _repository.signInWithGoogle());

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

  Future<void> _run(Future<void> Function() fn) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
    } catch (e) {
      _error = friendlyErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recoverySub?.cancel();
    super.dispose();
  }
}
