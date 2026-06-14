import 'package:flutter/material.dart';

class Category {
  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final int? id;
  final String name;
  final IconData icon;
  final Color color;

  Category copyWith({int? id, String? name, IconData? icon, Color? color}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}
