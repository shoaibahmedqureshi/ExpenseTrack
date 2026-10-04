import 'package:equatable/equatable.dart';

class ExpenseSplit extends Equatable {
  final String id;
  final String expenseId;
  final String familyGroupId;
  final String paidByMemberId;
  final Map<String, double> splitAmounts;
  final String currency;
  final DateTime createdAt;
  final String? description;
  final bool isSettled;
  final DateTime? settledDate;

  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.familyGroupId,
    required this.paidByMemberId,
    required this.splitAmounts,
    this.currency = 'PKR',
    required this.createdAt,
    this.description,
    this.isSettled = false,
    this.settledDate,
  });

  double get totalAmount => splitAmounts.values.fold(0.0, (sum, amount) => sum + amount);

  Map<String, double> getOwedByMember(String memberId) {
    final owed = <String, double>{};
    splitAmounts.forEach((memberIdKey, amount) {
      if (memberIdKey != paidByMemberId && amount > 0) {
        owed[memberIdKey] = amount;
      }
    });
    return owed;
  }

  ExpenseSplit copyWith({
    String? id,
    String? expenseId,
    String? familyGroupId,
    String? paidByMemberId,
    Map<String, double>? splitAmounts,
    String? currency,
    DateTime? createdAt,
    String? description,
    bool? isSettled,
    DateTime? settledDate,
  }) {
    return ExpenseSplit(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      paidByMemberId: paidByMemberId ?? this.paidByMemberId,
      splitAmounts: splitAmounts ?? this.splitAmounts,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      isSettled: isSettled ?? this.isSettled,
      settledDate: settledDate ?? this.settledDate,
    );
  }

  @override
  List<Object?> get props => [
    id,
    expenseId,
    familyGroupId,
    paidByMemberId,
    splitAmounts,
    currency,
    createdAt,
    description,
    isSettled,
    settledDate,
  ];
}
