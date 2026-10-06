/// Suggests one of the user's existing category names from a bank description.
/// Rules are ordered; the first one whose category exists wins. No match → null,
/// and the caller falls back to the user's chosen default.
class StatementCategorizer {
  StatementCategorizer._();

  static const _rules = <(String, List<String>)>[
    ('Salary', ['salary', 'payroll', 'stipend', 'wages', 'bonus']),
    ('Bills', [
      'k-electric', 'kelectric', 'k electric', 'lesco', 'iesco', 'fesco', 'gepco', 'mepco',
      'wapda', 'sui gas', 'sngpl', 'ssgc', 'ptcl', 'stormfiber', 'nayatel', 'internet bill',
      'electricity', 'utility', 'gas bill', 'water bill', 'jazz', 'zong', 'ufone', 'telenor',
      'mobile top', 'topup', 'top up', 'recharge',
    ]),
    ('Transport', [
      'uber', 'careem', 'indrive', 'bykea', 'fuel', 'petrol', 'pso', 'shell ', 'attock',
      'total parco', 'caltex', 'toll', 'm-tag', 'motorway', 'parking', 'airblue', 'pia ',
      'serene air', 'daewoo', 'railway',
    ]),
    ('Food', [
      'restaurant', 'cafe', 'coffee', 'kfc', 'mcdonald', 'pizza', 'burger', 'foodpanda',
      'food panda', 'cheezious', 'dominos', "domino's", 'subway', 'bakery', 'biryani',
      'grocery', 'supermarket', 'super market', 'imtiaz', 'carrefour', 'naheed', 'al-fatah',
      'al fatah', 'hyperstar', 'chase up', 'metro cash', 'savour', 'hardees', 'dine',
    ]),
    ('Health', [
      'pharmacy', 'pharma', 'hospital', 'clinic', 'doctor', 'medical', 'dvago', 'chughtai',
      'aga khan', 'shaukat khanum', 'medicine', 'dentist', 'laboratory', 'labs',
    ]),
    ('Entertainment', [
      'netflix', 'spotify', 'youtube', 'cinema', 'cineplex', 'imax', 'steam', 'playstation',
      'disney', 'prime video', 'itunes', 'google play',
    ]),
    ('Shopping', [
      'daraz', 'amazon', 'alibaba', 'aliexpress', 'mall', 'outfitters', 'khaadi', 'sapphire',
      'gul ahmed', 'breakout', 'bata ', 'servis', 'ideas', 'shopping',
    ]),
  ];

  /// [available] are the user's category names (any case).
  static String? suggest(String description, {required bool isExpense, required Iterable<String> available}) {
    final lower = ' ${description.toLowerCase()} ';
    final have = {for (final a in available) a.toLowerCase(): a};
    for (final (name, keywords) in _rules) {
      if (name == 'Salary' && isExpense) continue;
      if (name != 'Salary' && !isExpense) continue;
      final real = have[name.toLowerCase()];
      if (real == null) continue;
      if (keywords.any(lower.contains)) return real;
    }
    return null;
  }
}
