import 'package:flutter/material.dart';

/// Represents a bank that sends SMS for transactions
class SmsBank {
  final String id;
  final String name;
  final String shortCode;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final int parsedCount;

  SmsBank({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.color,
    required this.isEnabled,
    this.parsedCount = 0,
  });

  SmsBank copyWith({
    String? id,
    String? name,
    String? shortCode,
    IconData? icon,
    Color? color,
    bool? isEnabled,
    int? parsedCount,
  }) {
    return SmsBank(
      id: id ?? this.id,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isEnabled: isEnabled ?? this.isEnabled,
      parsedCount: parsedCount ?? this.parsedCount,
    );
  }
}
