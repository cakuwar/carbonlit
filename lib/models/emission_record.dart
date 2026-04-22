/// Model representing a single carbon emission record entry.
class EmissionRecord {
  final String? id;
  final String buildingName;
  final String month;
  final int year;
  final double energyConsumed;
  final String category;
  final double? emissionValue;
  final String? recordedBy;
  final DateTime createdAt;

  /// Whether this record is selected (checkbox) in the UI.
  bool isSelected;

  EmissionRecord({
    this.id,
    required this.buildingName,
    required this.month,
    required this.year,
    required this.energyConsumed,
    required this.category,
    this.emissionValue,
    this.recordedBy,
    DateTime? createdAt,
    this.isSelected = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to a map suitable for Supabase insertion.
  Map<String, dynamic> toMap() {
    return {
      'building_name': buildingName,
      'month': month,
      'year': year,
      'energy_consumed': energyConsumed,
      'category': category,
      if (emissionValue != null) 'emission_value': emissionValue,
      if (recordedBy != null) 'recorded_by': recordedBy,
    };
  }

  /// Create an [EmissionRecord] from a Supabase row.
  factory EmissionRecord.fromMap(Map<String, dynamic> map) {
    return EmissionRecord(
      id: map['id']?.toString(),
      buildingName: map['building_name'] as String? ?? '',
      month: map['month'] as String? ?? '',
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      energyConsumed: (map['energy_consumed'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? '',
      emissionValue: (map['emission_value'] as num?)?.toDouble(),
      recordedBy: map['recorded_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
