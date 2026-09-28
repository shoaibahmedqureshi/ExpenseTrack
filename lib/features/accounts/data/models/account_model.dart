import '../../domain/entities/account.dart';

class AccountModel extends Account {
  AccountModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.accountType,
    super.lastFour,
    required super.balance,
    super.iconKey,
    super.color,
    required super.isLinked,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      accountType: json['account_type'] as String,
      lastFour: json['last_four'] as String?,
      balance: double.parse(json['balance'].toString()),
      iconKey: json['icon_key'] as String?,
      color: json['color'] as String?,
      isLinked: json['is_linked'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'account_type': accountType,
    'last_four': lastFour,
    'balance': balance,
    'icon_key': iconKey,
    'color': color,
    'is_linked': isLinked,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
