import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/household_calculator.dart';
import '../domain/household_models.dart';

class HouseholdRepository {
  HouseholdRepository(this._db);
  final SupabaseClient _db;

  String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-01';

  Future<HouseholdOverview> overview(int familyId, DateTime month) async {
    final res = await _db.rpc('household_overview', params: {'p_family_id': familyId, 'p_month': _day(month)});
    return HouseholdOverview.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> setSharing(int familyId, bool enabled) =>
      _db.rpc('set_spending_sharing', params: {'p_family_id': familyId, 'p_enabled': enabled});

  Future<void> publish(int familyId, SharedSummary summary) => _db.rpc('publish_spending_summary', params: {
        'p_family_id': familyId,
        'p_from': _day(summary.from),
        'p_rows': [for (final r in summary.rows) r.toJson()],
      });

  Future<void> setBudget(int familyId, String? category, int cents) =>
      _db.rpc('set_family_budget', params: {'p_family_id': familyId, 'p_category': category, 'p_amount': cents / 100});

  Future<void> clearBudget(int familyId, String? category) =>
      _db.rpc('clear_family_budget', params: {'p_family_id': familyId, 'p_category': category});
}
