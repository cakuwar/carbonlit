import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/emission_record.dart';
import '../../models/category_item.dart';
import '../../services/emission_service.dart';
import '../../utils/carbon_calculator.dart';
import '../../widgets/category_icon_card.dart';
import '../../widgets/month_selector.dart';
import '../../widgets/emission_input_card.dart';
import '../../widgets/daily_emission_display.dart';
import '../../widgets/submitted_records_list.dart';

/// The main Carbon Calculator page content.
///
/// Allows admins to select a category, enter energy consumption data,
/// save emission records, and view submitted records.
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  // ── State ─────────────────────────────────────────────────────────────
  late int _selectedMonthIndex;
  int _selectedCategoryIndex = 4; // Villages
  String? _selectedBuilding;
  final TextEditingController _energyController = TextEditingController();
  List<EmissionRecord> _records = [];
  double _dailyEmission = 0.10;
  bool _isEditMode = false;

  final EmissionService _emissionService = EmissionService();

  // ── Months ────────────────────────────────────────────────────────────
  late final List<String> _months;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // ── Category question text per category ───────────────────────────────
  static const Map<String, String> _categoryQuestions = {
    'Academic': 'Which building would you like to count ?',
    'Laundry': 'Which laundry would you like to count ?',
    'Villages': 'Which village would you like to count ?',
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _months = _generateMonths();
    _selectedMonthIndex = _getCurrentMonthIndex();
    _loadRecords();
  }

  @override
  void dispose() {
    _energyController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  int _getCurrentMonthIndex() {
    final now = DateTime.now();
    final currentLabel = '${_monthNames[now.month - 1]} ${now.year}';
    final idx = _months.indexOf(currentLabel);
    return idx >= 0 ? idx : 0;
  }

  List<String> _generateMonths() {
    final months = <String>[];
    for (int year = 2024; year <= 2026; year++) {
      for (final month in _monthNames) {
        months.add('$month $year');
      }
    }
    return months;
  }

  Future<void> _loadRecords() async {
    final records = await _emissionService.fetchEmissionRecords();
    if (mounted) {
      setState(() => _records = records);
    }
  }

  Future<void> _saveRecord() async {
    final categoryLabel = defaultCategories[_selectedCategoryIndex].label;
    final hasDropdown = _categoryQuestions.containsKey(categoryLabel);

    // 1) Validate input
    if (hasDropdown && (_selectedBuilding == null || _selectedBuilding!.isEmpty)) {
      _showSnackBar('Please select a building');
      return;
    }

    final energyText = _energyController.text.trim();
    if (energyText.isEmpty) {
      _showSnackBar('Please enter energy consumed');
      return;
    }

    final energy = double.tryParse(energyText);
    if (energy == null || energy <= 0) {
      _showSnackBar('Please enter a valid energy value');
      return;
    }

    // 2) Create EmissionRecord
    final fullMonth = _months[_selectedMonthIndex];
    final parts = fullMonth.split(' ');
    final monthOnly = parts.first;
    final yearValue = int.parse(parts.last);
    final buildingName = hasDropdown ? _selectedBuilding! : categoryLabel;

    final record = EmissionRecord(
      buildingName: buildingName,
      month: monthOnly,
      year: yearValue,
      energyConsumed: energy,
      category: categoryLabel,
      emissionValue: calculateCarbonEmission(energy),
    );

    // 3) Call saveEmissionRecord()
    await _emissionService.saveEmissionRecord(record);

    // 4) Refresh record list
    await _loadRecords();

    // 5) Update Daily Emission display
    final emission = calculateCarbonEmission(energy);

    setState(() {
      _dailyEmission = emission == 0.0 ? 0.10 : emission;
      _selectedBuilding = null;
      _energyController.clear();
    });

    if (mounted) {
      _showSnackBar('Record saved successfully');
    }
  }

  Future<void> _deleteRecord(int index) async {
    final record = _records[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Delete record for "${record.buildingName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (record.id != null) {
        await _emissionService.deleteRecords([record.id!]);
      }
      await _loadRecords();
      if (mounted) _showSnackBar('Record deleted');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to delete: $e');
    }
  }

  Future<void> _editRecord(int index) async {
    final record = _records[index];
    final energyCtrl = TextEditingController(text: record.energyConsumed.toString());

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: ${record.buildingName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Month: ${record.month} ${record.year}'),
            const SizedBox(height: 12),
            TextField(
              controller: energyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Energy Consumed (kWh)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = double.tryParse(energyCtrl.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result <= 0) return;

    try {
      final updated = EmissionRecord(
        id: record.id,
        buildingName: record.buildingName,
        month: record.month,
        year: record.year,
        energyConsumed: result,
        category: record.category,
        emissionValue: calculateCarbonEmission(result),
        recordedBy: record.recordedBy,
      );
      await _emissionService.updateEmissionRecord(updated);
      await _loadRecords();
      if (mounted) _showSnackBar('Record updated');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to update: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final categoryLabel = defaultCategories[_selectedCategoryIndex].label;
    final hasDropdown = _categoryQuestions.containsKey(categoryLabel);
    final options = categoryBuildingOptions[categoryLabel] ?? [];
    final questionText =
        _categoryQuestions[categoryLabel] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        automaticallyImplyLeading: false,
        title: const Text(
          'Carbon Calculator',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // ── Month selector ─────────────────────────
            MonthSelector(
              currentMonth: _months[_selectedMonthIndex],
              onPrevious: _selectedMonthIndex > 0
                  ? () => setState(() => _selectedMonthIndex--)
                  : null,
              onNext: _selectedMonthIndex < _months.length - 1
                  ? () => setState(() => _selectedMonthIndex++)
                  : null,
            ),
            const SizedBox(height: 12),

            // ── Category grid ──────────────────────────
            _buildCategoryGrid(),
            const SizedBox(height: 14),

            // ── Section title pill ─────────────────────
            _buildSectionTitle(categoryLabel),
            const SizedBox(height: 14),

            // ── Input card ─────────────────────────────
            EmissionInputCard(
              questionText: questionText,
              buildingOptions: options,
              selectedBuilding: _selectedBuilding,
              energyController: _energyController,
              onBuildingChanged: (value) =>
                  setState(() => _selectedBuilding = value),
              onSave: _saveRecord,
              showDropdown: hasDropdown,
            ),
            const SizedBox(height: 20),

            // ── Daily emission ─────────────────────────
            DailyEmissionDisplay(emission: _dailyEmission),
            const SizedBox(height: 24),

            // ── Submitted records ──────────────────────
            SubmittedRecordsList(
              records: _records,
              isEditMode: _isEditMode,
              onEditToggle: () =>
                  setState(() => _isEditMode = !_isEditMode),
              onRecordToggle: (index) {
                setState(() {
                  _records[index].isSelected = !_records[index].isSelected;
                });
              },
              onDeleteRecord: (index) => _deleteRecord(index),
              onEditRecord: (index) => _editRecord(index),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Category grid builder ───────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: List.generate(defaultCategories.length, (index) {
        final cat = defaultCategories[index];
        return CategoryIconCard(
          icon: cat.icon,
          label: cat.label,
          isSelected: _selectedCategoryIndex == index,
          onTap: () {
            setState(() {
              _selectedCategoryIndex = index;
              _selectedBuilding = null;
            });
          },
        );
      }),
    );
  }

  // ── Section title pill ──────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      ),
    );
  }
}
