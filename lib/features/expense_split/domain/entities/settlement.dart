import 'package:equatable/equatable.dart';

class Settlement extends Equatable {
  final String id;
  final String familyGroupId;
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final String currency;
  final String? description;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime? settledAt;

  const Settlement({
    required this.id,
    required this.familyGroupId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    this.currency = 'PKR',
    this.description,
    this.isPaid = false,
    required this.createdAt,
    this.settledAt,
  });

  Settlement copyWith({
    String? id,
    String? familyGroupId,
    String? fromMemberId,
    String? toMemberId,
    double? amount,
    String? currency,
    String? description,
    bool? isPaid,
    DateTime? createdAt,
    DateTime? settledAt,
  }) {
    return Settlement(
      id: id ?? this.id,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      fromMemberId: fromMemberId ?? this.fromMemberId,
      toMemberId: toMemberId ?? this.toMemberId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      settledAt: settledAt ?? this.settledAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    familyGroupId,
    fromMemberId,
    toMemberId,
    amount,
    currency,
    description,
    isPaid,
    createdAt,
    settledAt,
  ];
}
