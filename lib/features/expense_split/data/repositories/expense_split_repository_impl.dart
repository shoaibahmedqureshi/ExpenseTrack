import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/repositories/expense_split_repository.dart';
import '../models/expense_split_model.dart';
import '../models/settlement_model.dart';

class ExpenseSplitRepositoryImpl implements ExpenseSplitRepository {
  final SupabaseClient supabase;

  ExpenseSplitRepositoryImpl({required this.supabase});

  @override
  Future<void> createExpenseSplit(ExpenseSplit split) async {
    final model = ExpenseSplitModel.fromEntity(split);
    await supabase.from('expense_splits').insert(model.toJson());
  }

  @override
  Future<ExpenseSplit?> getExpenseSplit(String id) async {
    final response = await supabase
        .from('expense_splits')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return ExpenseSplitModel.fromJson(response);
  }

  @override
  Future<List<ExpenseSplit>> getFamilySplits(String familyGroupId) async {
    final response = await supabase
        .from('expense_splits')
        .select()
        .eq('family_group_id', familyGroupId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => ExpenseSplitModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> updateExpenseSplit(ExpenseSplit split) async {
    final model = ExpenseSplitModel.fromEntity(split);
    await supabase.from('expense_splits').update(model.toJson()).eq('id', split.id);
  }

  @override
  Future<void> deleteExpenseSplit(String id) async {
    await supabase.from('expense_splits').delete().eq('id', id);
  }

  @override
  Future<List<Settlement>> getPendingSettlements(String familyGroupId) async {
    final response = await supabase
        .from('settlements')
        .select()
        .eq('family_group_id', familyGroupId)
        .eq('is_paid', false)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => SettlementModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> settlePayment(Settlement settlement) async {
    final model = SettlementModel.fromEntity(settlement);
    await supabase
        .from('settlements')
        .update({'is_paid': true, 'settled_at': DateTime.now().toIso8601String()})
        .eq('id', settlement.id);
  }

  @override
  Future<Map<String, double>> calculateBalances(String familyGroupId) async {
    final splits = await getFamilySplits(familyGroupId);
    final balances = <String, double>{};

    for (var split in splits) {
      split.splitAmounts.forEach((memberId, amount) {
        if (memberId != split.paidByMemberId) {
          balances.update(memberId, (current) => current + amount, ifAbsent: () => amount);
        }
      });
    }

    return balances;
  }
}
