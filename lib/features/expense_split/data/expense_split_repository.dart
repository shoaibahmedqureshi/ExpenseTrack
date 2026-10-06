import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/split_models.dart';

class ExpenseSplitRepository {
  ExpenseSplitRepository(this._db);
  final SupabaseClient _db;

  Future<List<ExpenseSplit>> splits(int familyId) async {
    final rows = await _db
        .from('expense_splits')
        .select('*, expense_split_shares(*)')
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => ExpenseSplit.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<SplitSettlement>> settlements(int familyId) async {
    final rows = await _db
        .from('expense_settlements')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => SplitSettlement.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// [sharesCents] is userId -> cents (zero shares are omitted by the caller);
  /// [percents] is only sent for percentage splits.
  Future<void> createSplit({
    required int familyId,
    required String paidBy,
    required String description,
    required int totalCents,
    required SplitType type,
    required Map<String, int> sharesCents,
    Map<String, double>? percents,
  }) async {
    await _db.rpc('create_expense_split', params: {
      'p_family_id': familyId,
      'p_paid_by': paidBy,
      'p_description': description,
      'p_total': totalCents / 100,
      'p_split_type': type.name,
      'p_shares': [
        for (final e in sharesCents.entries)
          {
            'user_id': e.key,
            'amount': e.value / 100,
            if (percents != null) 'percent': percents[e.key],
          }
      ],
    });
  }

  Future<void> recordSettlement({
    required int familyId,
    required String from,
    required String to,
    required int cents,
  }) async {
    await _db.rpc('record_settlement', params: {
      'p_family_id': familyId,
      'p_from': from,
      'p_to': to,
      'p_amount': cents / 100,
    });
  }

  Future<void> deleteSplit(int id) async {
    final gone = await _db.from('expense_splits').delete().eq('id', id).select('id');
    if ((gone as List).isEmpty) {
      throw Exception('Only the person who added this split, or the family admin, can delete it');
    }
  }

  Future<void> deleteSettlement(int id) async {
    final gone = await _db.from('expense_settlements').delete().eq('id', id).select('id');
    if ((gone as List).isEmpty) {
      throw Exception('Only the person who recorded this payment, or the family admin, can delete it');
    }
  }
}
