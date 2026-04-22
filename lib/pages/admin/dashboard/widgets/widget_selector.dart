import 'package:flutter/material.dart';

class WidgetSelector extends StatelessWidget {
  final bool showCarbonRing;
  final bool showCategoryCards;
  final bool showChart;
  final bool showGoals;
  final bool showTreeOffset;
  final bool showCampusEmissions;
  final Function(String key, bool value) onChanged;

  const WidgetSelector({
    super.key,
    required this.showCarbonRing,
    required this.showCategoryCards,
    required this.showChart,
    required this.showGoals,
    required this.showTreeOffset,
    required this.showCampusEmissions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Customize Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Toggle sections on or off',
              style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ),
          const SizedBox(height: 16),
          _buildToggle(
              'Carbon Ring', 'carbonRing', showCarbonRing, Icons.donut_large),
          _buildToggle('Category Cards', 'categoryCards', showCategoryCards,
              Icons.grid_view),
          _buildToggle(
              'Emission Chart', 'chart', showChart, Icons.bar_chart),
          _buildToggle(
              'Goals & Progress', 'goals', showGoals, Icons.flag),
          _buildToggle(
              'Tree Offset', 'treeOffset', showTreeOffset, Icons.park),
          _buildToggle('Campus Emissions', 'campusEmissions',
              showCampusEmissions, Icons.apartment),
        ],
      ),
    ),
    );
  }

  Widget _buildToggle(String label, String key, bool value, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF115925).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF115925), size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Switch(
        value: value,
        activeThumbColor: const Color(0xFF115925),
        onChanged: (newValue) => onChanged(key, newValue),
      ),
    );
  }
}
