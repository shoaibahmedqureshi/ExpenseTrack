import '../entities/expense_split.dart';
import '../entities/settlement.dart';

abstract class ExpenseSplitRepository {
  Future<void> createExpenseSplit(ExpenseSplit split);
  Future<ExpenseSplit?> getExpenseSplit(String id);
  Future<List<ExpenseSplit>> getFamilySplits(String familyGroupId);
  Future<void> updateExpenseSplit(ExpenseSplit split);
  Future<void> deleteExpenseSplit(String id);
  Future<List<Settlement>> getPendingSettlements(String familyGroupId);
  Future<void> settlePayment(Settlement settlement);
  Future<Map<String, double>> calculateBalances(String familyGroupId);
}
