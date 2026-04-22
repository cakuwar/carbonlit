import 'dart:math';
import 'package:flutter/material.dart';

/// Stunning campus-wide emission records section.
///
/// Shows admin-submitted building energy data grouped by category
/// (Academic, Mosque, Gym, Laundry, Villages, Pool) with animated
/// horizontal scroll cards and an expandable building breakdown.
class CampusEmissions extends StatefulWidget {
  /// List of emission records from the `emission_records` table.
  /// Each map has: building_name, category, month, year,
  /// energy_consumed (kWh), emission_value (kg CO₂e).
  final List<Map<String, dynamic>> records;

  const CampusEmissions({super.key, required this.records});

  @override
  State<CampusEmissions> createState() => _CampusEmissionsState();
}

class _CampusEmissionsState extends State<CampusEmissions>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  String? _expandedCategory;

  // Category visual config
  static const Map<String, _CatStyle> _styles = {
    'Academic': _CatStyle(Icons.school, [Color(0xFF115925), Color(0xFF1E8449)]),
    'Mosque': _CatStyle(Icons.mosque, [Color(0xFF1565C0), Color(0xFF42A5F5)]),
    'Gym': _CatStyle(Icons.fitness_center, [Color(0xFFE65100), Color(0xFFFF9800)]),
    'Laundry': _CatStyle(Icons.local_laundry_service, [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
    'Villages': _CatStyle(Icons.holiday_village, [Color(0xFF00695C), Color(0xFF26A69A)]),
    'Pool': _CatStyle(Icons.pool, [Color(0xFF0277BD), Color(0xFF4FC3F7)]),
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Aggregate records by category.
  Map<String, _CategoryData> _aggregate() {
    final map = <String, _CategoryData>{};
    for (final r in widget.records) {
      final cat = r['category'] as String? ?? 'Other';
      final kwh = (r['energy_consumed'] as num?)?.toDouble() ?? 0.0;
      final kg = (r['emission_value'] as num?)?.toDouble() ?? 0.0;
      final bldg = r['building_name'] as String? ?? '';
      final month = r['month'] as String? ?? '';
      final year = r['year'] as int? ?? 0;

      map.putIfAbsent(cat, () => _CategoryData());
      map[cat]!.totalKwh += kwh;
      map[cat]!.totalKg += kg;
      map[cat]!.recordCount++;
      map[cat]!.buildings.putIfAbsent(bldg, () => _BuildingData());
      map[cat]!.buildings[bldg]!.kwh += kwh;
      map[cat]!.buildings[bldg]!.kg += kg;
      map[cat]!.buildings[bldg]!.entries.add('$month $year');
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final data = _aggregate();
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final totalCampusKg =
        data.values.fold(0.0, (sum, c) => sum + c.totalKg);
    final totalCampusKwh =
        data.values.fold(0.0, (sum, c) => sum + c.totalKwh);
    final totalRecords =
        data.values.fold(0, (sum, c) => sum + c.recordCount);

    return FadeTransition(
      opacity: _fadeIn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF115925), Color(0xFF1E8449)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.apartment, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Campus Emissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF115925).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalRecords records',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115925),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Campus total banner ──
          _buildTotalBanner(totalCampusKg, totalCampusKwh),
          const SizedBox(height: 16),

          // ── Horizontal category cards ──
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final cat = data.keys.elementAt(i);
                final catData = data[cat]!;
                final style = _styles[cat] ??
                    const _CatStyle(
                        Icons.category, [Color(0xFF616161), Color(0xFF9E9E9E)]);
                return _buildCategoryCard(cat, catData, style, totalCampusKg);
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Expandable building breakdown ──
          ...data.entries.map(
              (e) => _buildCategoryExpander(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.apartment, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No campus emission records yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Admin-submitted building data will appear here',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBanner(double totalKg, double totalKwh) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF115925), Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF115925).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left — emission total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Campus Emission',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatNumber(totalKg),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        'kg CO\u2082e',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white24,
          ),
          // Right — energy consumed
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Energy Used',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNumber(totalKwh),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      'kWh',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String category,
    _CategoryData data,
    _CatStyle style,
    double totalCampusKg,
  ) {
    final pct =
        totalCampusKg > 0 ? (data.totalKg / totalCampusKg * 100) : 0.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedCategory =
              _expandedCategory == category ? null : category;
        });
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: style.gradient.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + percentage badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(style.icon, size: 20, color: Colors.white),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Emission value
            Text(
              data.totalKg.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const Text(
              'kg CO\u2082e',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            // Category name
            Text(
              category,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // Mini progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: min(pct / 100, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryExpander(String category, _CategoryData data) {
    final isExpanded = _expandedCategory == category;
    final style = _styles[category] ??
        const _CatStyle(
            Icons.category, [Color(0xFF616161), Color(0xFF9E9E9E)]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? style.gradient.first.withOpacity(0.4)
              : Colors.grey.shade200,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: style.gradient.first.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _expandedCategory =
                    _expandedCategory == category ? null : category;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: style.gradient.first.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(style.icon, size: 18, color: style.gradient.first),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                        Text(
                          '${data.buildings.length} building${data.buildings.length > 1 ? 's' : ''} · ${data.recordCount} record${data.recordCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${data.totalKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: style.gradient.first,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded building list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildBuildingList(data.buildings, style),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingList(
      Map<String, _BuildingData> buildings, _CatStyle style) {
    // Sort by emission descending
    final sorted = buildings.entries.toList()
      ..sort((a, b) => b.value.kg.compareTo(a.value.kg));

    final maxKg =
        sorted.isNotEmpty ? sorted.first.value.kg : 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        children: [
          Container(
            height: 1,
            color: Colors.grey.shade100,
            margin: const EdgeInsets.only(bottom: 10),
          ),
          ...sorted.map((e) {
            final ratio = maxKg > 0 ? e.value.kg / maxKg : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      Text(
                        '${e.value.kwh.toStringAsFixed(0)} kWh',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${e.value.kg.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: style.gradient.first,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        style.gradient.first.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatNumber(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(1);
  }
}

// ── Helper data classes ─────────────────────────────────────────────────
class _CatStyle {
  final IconData icon;
  final List<Color> gradient;
  const _CatStyle(this.icon, this.gradient);
}

class _CategoryData {
  double totalKwh = 0;
  double totalKg = 0;
  int recordCount = 0;
  Map<String, _BuildingData> buildings = {};
}

class _BuildingData {
  double kwh = 0;
  double kg = 0;
  List<String> entries = [];
}
