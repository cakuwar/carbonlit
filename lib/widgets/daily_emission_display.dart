import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Displays the daily carbon emission value.
///
/// Shows a title, large emission number, and unit subtitle.
class DailyEmissionDisplay extends StatelessWidget {
  /// The emission value in kg CO₂e/day.
  final double emission;

  const DailyEmissionDisplay({
    super.key,
    required this.emission,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Daily Emission :',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          emission.toStringAsFixed(2),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '(kg CO₂e/day)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
