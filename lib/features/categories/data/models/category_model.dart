import 'package:flutter/material.dart';
import '../../../../core/constants/icon_map.dart';
import '../../domain/entities/category.dart';

class CategoryModel extends Category {
  const CategoryModel({
    super.id,
    required super.name,
    required super.icon,
    required super.color,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        // Resolved from a const lookup table — safe for tree-shaking.
        icon: iconFromKey(map['icon_key'] as String),
        color: Color(map['color'] as int),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon_key': iconToKey(icon),
        'color': color.value,
      };

  factory CategoryModel.fromEntity(Category category) => CategoryModel(
        id: category.id,
        name: category.name,
        icon: category.icon,
        color: category.color,
      );
}
