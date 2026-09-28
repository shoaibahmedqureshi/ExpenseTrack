import 'package:flutter/material.dart';

class Account {
  final int id;
  final String userId;
  final String name;
  final String accountType; // checking, savings, wallet, cash, etc.
  final String? lastFour; // last 4 digits or identifier
  final double balance;
  final String? iconKey;
  final String? color; // hex color code
  final bool isLinked;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    this.lastFour,
    required this.balance,
    this.iconKey,
    this.color,
    required this.isLinked,
    required this.createdAt,
    required this.updatedAt,
  });

  Color getDisplayColor() {
    if (color != null && color!.isNotEmpty) {
      return Color(int.parse(color!.replaceFirst('#', '0xff')));
    }
    // Default colors by account type
    switch (accountType.toLowerCase()) {
      case 'checking':
        return const Color(0xFF667EEA);
      case 'savings':
        return const Color(0xFF10B981);
      case 'wallet':
        return const Color(0xFFEF4444);
      case 'cash':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF667EEA);
    }
  }

  IconData getDisplayIcon() {
    if (iconKey == null) {
      return _getDefaultIcon();
    }
    return _iconFromKey(iconKey!);
  }

  IconData _getDefaultIcon() {
    switch (accountType.toLowerCase()) {
      case 'checking':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'cash':
        return Icons.payments;
      default:
        return Icons.account_balance;
    }
  }

  IconData _iconFromKey(String key) {
    // Map icon string keys to IconData
    // This allows flexibility for future icon customization
    switch (key.toLowerCase()) {
      case 'account_balance':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'payments':
        return Icons.payments;
      case 'credit_card':
        return Icons.credit_card;
      case 'mobile':
        return Icons.mobile_friendly;
      default:
        return _getDefaultIcon();
    }
  }

  String get displayIdentifier => lastFour ?? accountType;

  Account copyWith({
    int? id,
    String? userId,
    String? name,
    String? accountType,
    String? lastFour,
    double? balance,
    String? iconKey,
    String? color,
    bool? isLinked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      lastFour: lastFour ?? this.lastFour,
      balance: balance ?? this.balance,
      iconKey: iconKey ?? this.iconKey,
      color: color ?? this.color,
      isLinked: isLinked ?? this.isLinked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
