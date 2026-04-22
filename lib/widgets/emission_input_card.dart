import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// A rounded card containing emission data input fields.
///
/// Includes a dropdown for building selection, a text field for energy
/// consumption, and a Save button.
class EmissionInputCard extends StatelessWidget {
  /// The question prompt shown above the dropdown.
  final String questionText;

  /// List of building / facility options for the dropdown.
  final List<String> buildingOptions;

  /// Currently selected building value.
  final String? selectedBuilding;

  /// Controller for the energy consumed text field.
  final TextEditingController energyController;

  /// Called when the dropdown selection changes.
  final ValueChanged<String?> onBuildingChanged;

  /// Called when the Save button is pressed.
  final VoidCallback onSave;

  /// Whether to show the dropdown selector.
  /// When false, only the energy text field and save button are shown.
  final bool showDropdown;

  const EmissionInputCard({
    super.key,
    required this.questionText,
    required this.buildingOptions,
    required this.selectedBuilding,
    required this.energyController,
    required this.onBuildingChanged,
    required this.onSave,
    this.showDropdown = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.lightGrey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Question + Dropdown (conditional) ─────────
            if (showDropdown) ...[
              Text(
                questionText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.softGreen, width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedBuilding,
                    hint: Text(
                      'Select an option',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.primaryGreen,
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                    ),
                    items: buildingOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: onBuildingChanged,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Energy label ──────────────────────────────
            const Text(
              'Energy Consumed (kWh)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),

            // ── Text field ────────────────────────────────
            TextField(
              controller: energyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Enter energy in kWh',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.softGreen, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.softGreen, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primaryGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Save button ───────────────────────────────
            Center(
              child: SizedBox(
                width: 140,
                height: 44,
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Save',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
