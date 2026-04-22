import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A reusable square icon card for category selection.
///
/// Displays an icon inside a rounded container with a selected / unselected
/// state. Can be used across different pages (admin, calculator, dashboard).
class CategoryIconCard extends StatelessWidget {
  /// The icon to display.
  final IconData icon;

  /// Label for accessibility / semantics.
  final String label;

  /// Whether this card is currently selected.
  final bool isSelected;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

  const CategoryIconCard({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryGreen : AppColors.lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 32,
                color: isSelected ? Colors.white : AppColors.primaryGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
