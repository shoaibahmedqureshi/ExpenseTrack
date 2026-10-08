/// Pure split maths. All money is whole cents so shares always add up exactly.
class Debt {
  const Debt(this.from, this.to, this.cents);
  final String from;
  final String to;
  final int cents;

  @override
  bool operator ==(Object o) =>
      o is Debt && o.from == from && o.to == to && o.cents == cents;
  @override
  int get hashCode => Object.hash(from, to, cents);
  @override
  String toString() => 'Debt($from -> $to, $cents)';
}

class SplitCalculator {
  SplitCalculator._();

  /// Converts a user-entered amount to cents, or null if it isn't a positive,
  /// finite number with at most 2 decimals.
  static int? toCents(String input) {
    final s = input.trim().replaceAll(',', '');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final whole = int.parse(parts[0]);
    final frac = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return whole * 100 + frac;
  }

  /// Equal split. The leftover cents go one each to the first members in order.
  static Map<String, int> equalShares(int totalCents, List<String> members) {
    if (members.isEmpty) return {};
    final base = totalCents ~/ members.length;
    var rest = totalCents - base * members.length;
    final out = <String, int>{};
    for (final m in members) {
      out[m] = base + (rest > 0 ? 1 : 0);
      if (rest > 0) rest--;
    }
    return out;
  }

  /// Percentage split using the largest-remainder method so the shares sum to
  /// [totalCents] exactly. Returns null if percentages don't total 100.
  static Map<String, int>? percentShares(
      int totalCents, Map<String, double> percents) {
    if (percents.isEmpty) return null;
    final sum = percents.values.fold<double>(0, (a, b) => a + b);
    if ((sum - 100).abs() > 0.005 || percents.values.any((p) => p < 0)) {
      return null;
    }
    final entries = percents.entries.toList();
    final floors = <String, int>{};
    final fracs = <MapEntry<String, double>>[];
    var assigned = 0;
    for (final e in entries) {
      final exact = totalCents * e.value / 100;
      final fl = exact.floor();
      floors[e.key] = fl;
      assigned += fl;
      fracs.add(MapEntry(e.key, exact - fl));
    }
    var left = totalCents - assigned;
    final order = List<int>.generate(fracs.length, (i) => i)
      ..sort((a, b) {
        final c = fracs[b].value.compareTo(fracs[a].value);
        return c != 0 ? c : a.compareTo(b);
      });
    for (final i in order) {
      if (left <= 0) break;
      floors[fracs[i].key] = floors[fracs[i].key]! + 1;
      left--;
    }
    return floors;
  }

  /// Null when valid, otherwise a user-facing reason.
  static String? validateAmountShares(int totalCents, Map<String, int> shares) {
    if (totalCents <= 0) return 'Enter a total amount greater than zero';
    if (shares.isEmpty || shares.values.every((c) => c == 0)) {
      return 'Choose at least one person to split with';
    }
    if (shares.values.any((c) => c < 0)) return 'Amounts cannot be negative';
    final sum = shares.values.fold<int>(0, (a, b) => a + b);
    if (sum != totalCents) {
      final diff = (totalCents - sum).abs();
      final label = (diff / 100).toStringAsFixed(2);
      return sum < totalCents
          ? 'Amounts are $label short of the total'
          : 'Amounts are $label over the total';
    }
    return null;
  }

  /// Net position per person: positive = is owed money, negative = owes.
  /// [splits] are (payer, shares) pairs; [payments] are (from, to, cents).
  static Map<String, int> netBalances(
    Iterable<({String paidBy, Map<String, int> shares})> splits,
    Iterable<({String from, String to, int cents})> payments,
  ) {
    final net = <String, int>{};
    void add(String id, int c) => net[id] = (net[id] ?? 0) + c;
    for (final s in splits) {
      s.shares.forEach((member, cents) {
        if (member == s.paidBy) return;
        add(s.paidBy, cents);
        add(member, -cents);
      });
    }
    for (final p in payments) {
      add(p.from, p.cents);
      add(p.to, -p.cents);
    }
    net.removeWhere((_, v) => v == 0);
    return net;
  }

  /// Fewest-transfers settlement: repeatedly match the biggest debtor with the
  /// biggest creditor.
  static List<Debt> simplifyDebts(Map<String, int> net) {
    final creditors = net.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final debtors = net.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final cred = {for (final e in creditors) e.key: e.value};
    final debt = {for (final e in debtors) e.key: -e.value};
    final out = <Debt>[];
    while (cred.isNotEmpty && debt.isNotEmpty) {
      final c = cred.entries.reduce((a, b) => b.value > a.value ? b : a);
      final d = debt.entries.reduce((a, b) => b.value > a.value ? b : a);
      final amt = c.value < d.value ? c.value : d.value;
      out.add(Debt(d.key, c.key, amt));
      if (c.value == amt) {
        cred.remove(c.key);
      } else {
        cred[c.key] = c.value - amt;
      }
      if (d.value == amt) {
        debt.remove(d.key);
      } else {
        debt[d.key] = d.value - amt;
      }
    }
    return out;
  }

  /// What [me] owes in total and is owed in total, from simplified [debts].
  static ({int owe, int owed}) myTotals(List<Debt> debts, String me) {
    var owe = 0, owed = 0;
    for (final d in debts) {
      if (d.from == me) owe += d.cents;
      if (d.to == me) owed += d.cents;
    }
    return (owe: owe, owed: owed);
  }

  /// What the person owes and is owed across several ledgers. Each ledger's net is one signed figure, and
  /// ledgers are never netted against each other: money owed in one group does not pay a debt in another.
  static ({int owe, int owed}) overviewTotals(Iterable<int> nets) {
    var owe = 0, owed = 0;
    for (final n in nets) {
      if (n < 0) owe += -n;
      if (n > 0) owed += n;
    }
    return (owe: owe, owed: owed);
  }
}
