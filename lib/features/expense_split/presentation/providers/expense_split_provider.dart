import 'package:flutter/foundation.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/repositories/expense_split_repository.dart';

class ExpenseSplitProvider extends ChangeNotifier {
  final ExpenseSplitRepository repository;

  List<ExpenseSplit> _splits = [];
  List<Settlement> _pendingSettlements = [];
  Map<String, double> _balances = {};
  bool _isLoading = false;
  String? _error;

  ExpenseSplitProvider({required this.repository});

  List<ExpenseSplit> get splits => _splits;
  List<Settlement> get pendingSettlements => _pendingSettlements;
  Map<String, double> get balances => _balances;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFamilySplits(String familyGroupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _splits = await repository.getFamilySplits(familyGroupId);
      _pendingSettlements = await repository.getPendingSettlements(familyGroupId);
      _balances = await repository.calculateBalances(familyGroupId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSplit(ExpenseSplit split) async {
    try {
      await repository.createExpenseSplit(split);
      _splits.add(split);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> settlePayment(Settlement settlement) async {
    try {
      await repository.settlePayment(settlement);
      _pendingSettlements.removeWhere((s) => s.id == settlement.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clear() {
    _splits = [];
    _pendingSettlements = [];
    _balances = {};
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
