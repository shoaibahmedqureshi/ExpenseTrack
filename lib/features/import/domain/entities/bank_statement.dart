class BankStatementTransaction {
  final DateTime date;
  final String description;
  final double amount;
  final String? reference;
  final String type; // debit, credit

  BankStatementTransaction({
    required this.date,
    required this.description,
    required this.amount,
    this.reference,
    required this.type,
  });

  bool get isExpense => type.toLowerCase() == 'debit';
}

class BankStatement {
  final String bankName;
  final String accountNumber;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<BankStatementTransaction> transactions;
  final double openingBalance;
  final double closingBalance;

  BankStatement({
    required this.bankName,
    required this.accountNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.transactions,
    required this.openingBalance,
    required this.closingBalance,
  });

  double get totalDebits =>
      transactions.where((t) => t.isExpense).fold(0, (sum, t) => sum + t.amount);
  double get totalCredits =>
      transactions.where((t) => !t.isExpense).fold(0, (sum, t) => sum + t.amount);
}
