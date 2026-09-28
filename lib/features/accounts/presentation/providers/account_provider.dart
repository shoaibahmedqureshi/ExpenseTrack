import 'package:flutter/material.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';

class AccountProvider extends ChangeNotifier {
  final AccountRepository repository;

  List<Account> _accounts = [];
  bool _isLoading = false;
  String? _error;
  bool hasLoadedOnce = false;

  AccountProvider({required this.repository});

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accounts = await repository.getAllAccounts();
      hasLoadedOnce = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (!hasLoadedOnce) {
        _accounts = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Account?> create({
    required String name,
    required String accountType,
    String? lastFour,
    required double balance,
    String? iconKey,
    String? color,
  }) async {
    try {
      final account = Account(
        id: 0,
        userId: '', // Will be set by backend
        name: name,
        accountType: accountType,
        lastFour: lastFour,
        balance: balance,
        iconKey: iconKey,
        color: color,
        isLinked: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await repository.createAccount(account);
      _accounts.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> updateBalance(int accountId, double newBalance) async {
    try {
      final index = _accounts.indexWhere((a) => a.id == accountId);
      if (index >= 0) {
        final updated = _accounts[index].copyWith(balance: newBalance);
        await repository.updateAccount(updated);
        _accounts[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> delete(int accountId) async {
    try {
      await repository.deleteAccount(accountId);
      _accounts.removeWhere((a) => a.id == accountId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  double getTotalBalance() {
    return _accounts.fold(0, (sum, account) => sum + account.balance);
  }
}
