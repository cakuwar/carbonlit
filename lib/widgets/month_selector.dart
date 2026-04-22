import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A horizontal month selector with left / right navigation arrows.
///
/// Displays the current month string (e.g. "January 2025") centred
/// between two arrow buttons.
class MonthSelector extends StatelessWidget {
  /// The currently displayed month text.
  final String currentMonth;

  /// Called when the user taps the left (previous) arrow.
  final VoidCallback? onPrevious;

  /// Called when the user taps the right (next) arrow.
  final VoidCallback? onNext;

  const MonthSelector({
    super.key,
    required this.currentMonth,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.darkText),
            onPressed: onPrevious,
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          Text(
            currentMonth,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.darkText),
            onPressed: onNext,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
