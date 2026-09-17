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

  // Without this, two Category instances representing the same DB row
  // (e.g. one loaded via an Expense join, one from CategoryProvider's own
  // list) are only `==` if they're the literal same object — which breaks
  // DropdownButtonFormField's internal value-matching whenever categories
  // get reloaded/recreated between a user's selection and the next build.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          color == other.color;

  @override
  int get hashCode => Object.hash(id, name, icon, color);
}
