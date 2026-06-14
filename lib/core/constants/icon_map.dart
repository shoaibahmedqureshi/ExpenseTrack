import 'package:flutter/material.dart';

// All icons used by categories must be listed here as compile-time constants
// so Flutter's tree-shaker can include only what's needed in release builds.
const Map<String, IconData> categoryIcons = {
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'favorite': Icons.favorite,
  'movie': Icons.movie,
  'account_balance_wallet': Icons.account_balance_wallet,
  'category': Icons.category,
};

IconData iconFromKey(String key) =>
    categoryIcons[key] ?? Icons.help_outline;

String iconToKey(IconData icon) =>
    categoryIcons.entries
        .firstWhere(
          (e) => e.value.codePoint == icon.codePoint,
          orElse: () => const MapEntry('category', Icons.category),
        )
        .key;
