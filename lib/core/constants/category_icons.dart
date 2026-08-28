import 'package:flutter/material.dart';

class CategoryIcons {
  CategoryIcons._();

  static IconData getIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Education':
        return Icons.school_rounded;
      case 'Utilities':
        return Icons.electrical_services_rounded;
      case 'Subscription':
        return Icons.subscriptions_rounded;
      case 'Other':
      default:
        return Icons.category_rounded;
    }
  }

  /// Returns a muted, balanced color for each category.
  /// These mid-saturation tones work well on both light and dark surfaces.
  static Color getColor(String category) {
    switch (category) {
      case 'Food':
        return const Color(0xFFEA580C); // Orange 600
      case 'Transport':
        return const Color(0xFF2563EB); // Blue 600
      case 'Entertainment':
        return const Color(0xFF9333EA); // Purple 600
      case 'Shopping':
        return const Color(0xFFDB2777); // Pink 600
      case 'Education':
        return const Color(0xFF0D9488); // Teal 600
      case 'Utilities':
        return const Color(0xFFD97706); // Amber 600
      case 'Subscription':
        return const Color(0xFFDC2626); // Red 600
      case 'Other':
      default:
        return const Color(0xFF6B7280); // Gray 500
    }
  }
}
