import 'package:flutter/material.dart';

class CategorySummary extends StatelessWidget {
  final Map<String, double> categoryEmissions;

  const CategorySummary({super.key, required this.categoryEmissions});

  static const Map<String, IconData> _icons = {
    'Transportation': Icons.directions_car,
    'Gadgets': Icons.devices,
    'Accommodation': Icons.hotel,
  };

  static const Map<String, Color> _colors = {
    'Transportation': Color(0xFF115925),
    'Gadgets': Color(0xFF2196F3),
    'Accommodation': Color(0xFFFF9800),
  };

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: categoryEmissions.entries.map((entry) {
        final color = _colors[entry.key] ?? Colors.grey;
        final icon = _icons[entry.key] ?? Icons.category;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const Spacer(),
                  Icon(
                    entry.value > 0
                        ? Icons.trending_up
                        : Icons.trending_flat,
                    size: 16,
                    color: color,
                  ),
                ],
              ),
              Text(
                '${entry.value.toStringAsFixed(1)} kg',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
