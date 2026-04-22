import 'package:flutter/material.dart';

/// Represents a category for carbon emission classification.
class CategoryItem {
  final IconData icon;
  final String label;

  const CategoryItem({required this.icon, required this.label});
}

/// Default admin categories used across Calculator and Dashboard pages.
const List<CategoryItem> defaultCategories = [
  CategoryItem(icon: Icons.account_balance, label: 'Academic'),
  CategoryItem(icon: Icons.mosque, label: 'Mosque'),
  CategoryItem(icon: Icons.fitness_center, label: 'Gym'),
  CategoryItem(icon: Icons.local_laundry_service, label: 'Laundry'),
  CategoryItem(icon: Icons.holiday_village, label: 'Villages'),
  CategoryItem(icon: Icons.pool, label: 'Pool'),
];

/// Building / facility options per category.
const Map<String, List<String>> categoryBuildingOptions = {
  'Academic': ['Block A', 'Block B', 'Block C', 'Block D','Block E','Block F','Cetal','Block I','Block J','Block K','Block L', 'Block M','Block N','Block O','Block P','Block Q'],
  'Laundry': ['Village 1', 'Village 2', 'Village 3', 'Village 4', 'Village 5', 'Village 6'],
  'Villages': ['Village 1', 'Village 2', 'Village 3', 'Village 4', 'Village 5', 'Village 6'],
};
