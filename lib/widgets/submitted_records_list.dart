import 'package:flutter/material.dart';
import '../models/emission_record.dart';
import '../theme/app_colors.dart';

/// Displays a scrollable list of submitted emission records with an
/// optional edit mode that shows checkboxes.
class SubmittedRecordsList extends StatelessWidget {
  /// The list of emission records to display.
  final List<EmissionRecord> records;

  /// Whether the list is in edit mode (checkboxes interactive).
  final bool isEditMode;

  /// Called when the Edit / Done button is toggled.
  final VoidCallback onEditToggle;

  /// Called when a record's checkbox is toggled (passes the record index).
  final ValueChanged<int> onRecordToggle;

  /// Called when a record is deleted (passes the record index).
  final ValueChanged<int>? onDeleteRecord;

  /// Called when a record is edited (passes the record index).
  final ValueChanged<int>? onEditRecord;

  const SubmittedRecordsList({
    super.key,
    required this.records,
    required this.isEditMode,
    required this.onEditToggle,
    required this.onRecordToggle,
    this.onDeleteRecord,
    this.onEditRecord,
  });

  /// Format a number with comma thousands separators.
  String _formatNumber(double value) {
    final str = value.toInt().toString();
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ──────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Submitted Records :',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: onEditToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isEditMode ? 'Done' : 'Edit',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Table ───────────────────────────────────────
        SizedBox(
          height: 300,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: isEditMode ? 550 : 480,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // ── Table header ─────────────────────────
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(8)),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 36),
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Building',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Month',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Energy Consumed (kWh)',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          if (isEditMode)
                            const SizedBox(
                              width: 72,
                              child: Text(
                                'Actions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Table rows ──────────────────────────
                    if (records.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No records yet',
                            style: TextStyle(color: AppColors.grey, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            final isAlternate = index.isOdd;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: isAlternate
                                    ? AppColors.lightGreen.withValues(alpha: 0.5)
                                    : Colors.white,
                                border: index < records.length - 1
                                    ? Border(
                                        bottom:
                                            BorderSide(color: Colors.grey[200]!))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 36,
                                    child: Checkbox(
                                      value: record.isSelected,
                                      onChanged: isEditMode
                                          ? (_) => onRecordToggle(index)
                                          : null,
                                      activeColor: AppColors.primaryGreen,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      record.buildingName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      record.month,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _formatNumber(record.energyConsumed),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                  ),
                                  if (isEditMode)
                                    SizedBox(
                                      width: 72,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => onEditRecord?.call(index),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.edit, size: 18, color: AppColors.primaryGreen),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => onDeleteRecord?.call(index),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.delete, size: 18, color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
