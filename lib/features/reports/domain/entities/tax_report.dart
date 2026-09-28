class TaxReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpenses;
  final double totalTax;
  final Map<dynamic, double> expensesByCategory;
  final List<dynamic> deductibleItems;
  final String currency;
  final double taxRate; // configurable tax rate (0.15 = 15%)

  TaxReport({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalTax,
    required this.expensesByCategory,
    required this.deductibleItems,
    this.currency = 'PKR',
    this.taxRate = 0.15, // default: 15%
  });

  double get netIncome => totalIncome - totalExpenses;
  double get estimatedTaxLiability => netIncome * taxRate;
  double get taxRatePercentage => taxRate * 100;

  String get reportTitle => 'Tax Report ${startDate.year}';
}

class TaxDeductibleItem {
  final String category;
  final double amount;
  final DateTime date;
  final String description;
  final double taxRate; // varies by item type

  TaxDeductibleItem({
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    required this.taxRate,
  });

  double get estimatedTaxBenefit => amount * (taxRate / 100);
}
