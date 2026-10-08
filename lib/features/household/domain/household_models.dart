int _cents(Object? numeric) => (((numeric as num?) ?? 0) * 100).round();

/// One person's place in the household view for a month.
class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.isOwner,
    required this.sharing,
    required this.categories,
  });

  final String userId;
  final String name;
  final String email;
  final bool isOwner;

  /// Whether this person has chosen to share their monthly totals. Everything else about them stays private.
  final bool sharing;

  /// Category -> cents spent this month. Empty when [sharing] is false.
  final Map<String, int> categories;

  int get totalCents => categories.values.fold(0, (a, b) => a + b);

  factory HouseholdMember.fromJson(Map<String, dynamic> j) => HouseholdMember(
        userId: j['user_id'] as String,
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        isOwner: j['is_owner'] == true,
        sharing: j['sharing'] == true,
        categories: {
          for (final c in (j['categories'] as List? ?? const []))
            (c as Map)['category'] as String: _cents(c['spent']),
        },
      );
}

/// The household's monthly budget: [category] null means the overall budget.
class HouseholdBudget {
  const HouseholdBudget({required this.category, required this.amountCents});
  final String? category;
  final int amountCents;

  factory HouseholdBudget.fromJson(Map<String, dynamic> j) =>
      HouseholdBudget(category: j['category'] as String?, amountCents: _cents(j['amount']));
}

class HouseholdOverview {
  const HouseholdOverview({required this.month, required this.members, required this.budgets});
  final DateTime month;
  final List<HouseholdMember> members;
  final List<HouseholdBudget> budgets;

  factory HouseholdOverview.empty(DateTime month) => HouseholdOverview(month: month, members: const [], budgets: const []);

  factory HouseholdOverview.fromJson(Map<String, dynamic> j) {
    final m = DateTime.parse(j['month'] as String);
    return HouseholdOverview(
      month: DateTime(m.year, m.month),
      members: [for (final x in (j['members'] as List? ?? const [])) HouseholdMember.fromJson(Map<String, dynamic>.from(x as Map))],
      budgets: [for (final x in (j['budgets'] as List? ?? const [])) HouseholdBudget.fromJson(Map<String, dynamic>.from(x as Map))],
    );
  }

  HouseholdMember? member(String userId) => members.where((m) => m.userId == userId).firstOrNull;
}
