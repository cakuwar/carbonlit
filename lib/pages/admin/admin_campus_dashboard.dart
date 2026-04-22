import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Campus-wide analytics dashboard for admin users.
///
/// Inspired by Power BI style dashboards — shows KPI cards,
/// emission trend line, facility-type pie chart, top 5 zones,
/// and a trees-planted meter.
class AdminCampusDashboard extends StatefulWidget {
  const AdminCampusDashboard({super.key});

  @override
  State<AdminCampusDashboard> createState() => _AdminCampusDashboardState();
}

class _AdminCampusDashboardState extends State<AdminCampusDashboard> {
  static const Color _primary = Color(0xFF115925);

  bool _isLoading = true;

  // KPI values
  double _totalCampusEmission = 0.0; // kg CO₂e
  int _activeUsers = 0;
  double _targetPercent = 0.0; // 0–100
  int _totalTreesNeeded = 0;

  // Emission by facility type
  Map<String, double> _facilityEmissions = {};

  // Monthly trend data (month label → total kg)
  List<_TrendPoint> _trendData = [];

  // Top 5 high-emission zones
  List<MapEntry<String, double>> _topZones = [];

  // All campus records
  List<Map<String, dynamic>> _campusRecords = [];

  // User emission totals (for leaderboard/active users)
  int _totalProfiles = 0;

  // User leaderboard (lowest emission first)
  List<Map<String, dynamic>> _leaderboardData = [];

  // AI suggestion
  String? _aiSuggestion;
  bool _loadingSuggestion = false;

  // Period filter
  String _selectedPeriod = 'All Time';
  double _prevPeriodEmission = 0.0;

  // Health score
  String _healthGrade = 'N/A';
  double _reductionPercent = 0.0; // % reduction vs same period last year

  // Custom month picker
  DateTime? _selectedCustomMonth;

  // Month label order (abbreviated, for display)
  static const List<String> _monthOrder = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Full month names (as saved by calculator)
  static const List<String> _monthFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // Target reduction goal: 15% reduction vs same period last year
  static const double _targetReduction = 15.0;

  /// Convert a month string (full or abbreviated) to 1-based month index.
  /// Returns 0 if not found.
  static int _monthIndex(String monthStr) {
    final fi = _monthFull.indexOf(monthStr);
    if (fi >= 0) return fi + 1;
    final ai = _monthOrder.indexOf(monthStr);
    if (ai >= 0) return ai + 1;
    return 0;
  }

  /// Return the abbreviated month name for a 1-based month integer.
  static String _monthAbbrFromInt(int month) {
    if (month < 1 || month > 12) return '';
    return _monthOrder[month - 1];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // ── 1. Campus emission records ──
      _campusRecords = await supabase
          .from('emission_records')
          .select(
              'building_name, category, month, year, energy_consumed, emission_value, created_at')
          .order('created_at', ascending: true);

      // ── 2. All profiles ──
      final profiles = await supabase
          .from('profiles')
          .select('id, role, first_name, last_name');
      _totalProfiles = profiles.length;

      // ── 3. User records for leaderboard & active user count ──
      final allTransport = await supabase
          .from('transport_records')
          .select('user_id, daily_emission');
      final allGadgets = await supabase
          .from('gadget_records')
          .select('user_id, daily_emission');
      final allAccom = await supabase
          .from('accommodation_records')
          .select('user_id, daily_emission');

      final activeUserIds = <String>{};
      final userTotals = <String, double>{};
      for (final r in [...allTransport, ...allGadgets, ...allAccom]) {
        final uid = r['user_id'] as String? ?? '';
        if (uid.isNotEmpty) {
          activeUserIds.add(uid);
          userTotals[uid] = (userTotals[uid] ?? 0.0) +
              ((r['daily_emission'] as num?)?.toDouble() ?? 0.0);
        }
      }

      final leaderboard = <Map<String, dynamic>>[];
      for (final p in profiles) {
        final pId = p['id'] as String? ?? '';
        final pName =
            '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
        if (userTotals.containsKey(pId)) {
          leaderboard.add({
            'id': pId,
            'name': pName.isEmpty ? 'Unknown' : pName,
            'role': p['role'] as String? ?? 'student',
            'total': userTotals[pId]!,
          });
        }
      }
      leaderboard.sort(
          (a, b) => (a['total'] as double).compareTo(b['total'] as double));

      if (mounted) {
        setState(() {
          _activeUsers = activeUserIds.length;
          _leaderboardData = leaderboard;
        });
      }

      // Aggregate using selected period filter
      _applyPeriodFilter(_selectedPeriod, isInitialLoad: true);
      _fetchCampusAI();
    } catch (e) {
      debugPrint('Error loading campus dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _primary,
        title: const Text(
          'Campus Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            tooltip: 'Export PDF Report',
            onPressed: _isLoading ? null : _exportReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : RefreshIndicator(
              color: _primary,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ══════════════════════════════════
                    // Campus Health Score Banner
                    // ══════════════════════════════════
                    _buildHealthScoreBanner(),
                    const SizedBox(height: 14),

                    // ══════════════════════════════════
                    // Period Filter
                    // ══════════════════════════════════
                    _buildPeriodFilter(),
                    const SizedBox(height: 18),

                    // ══════════════════════════════════
                    // KPI Cards Row
                    // ══════════════════════════════════
                    _buildKpiRow(),
                    const SizedBox(height: 20),

                    // ══════════════════════════════════
                    // Campus Emission Trend (line chart)
                    // ══════════════════════════════════
                    _buildSectionTitle(
                        'Campus-Wide Carbon Emission Trend', Icons.show_chart),
                    const SizedBox(height: 12),
                    _buildTrendChart(),
                    const SizedBox(height: 24),

                    // ══════════════════════════════════
                    // Emissions by Facility Type (pie)
                    // ══════════════════════════════════
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pie chart
                        Expanded(child: _buildPieChart()),
                        const SizedBox(width: 12),
                        // Top 5 High-Emission Zones
                        Expanded(child: _buildTopZones()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ══════════════════════════════════
                    // Your Impact — Trees Planted Gauge
                    // ══════════════════════════════════
                    _buildTreesGauge(),
                    const SizedBox(height: 24),

                    // ══════════════════════════════════
                    // AI Campus Recommendations
                    // ══════════════════════════════════
                    _buildSectionTitle(
                        'AI Campus Recommendations', Icons.psychology),
                    const SizedBox(height: 12),
                    _buildAICard(),
                    const SizedBox(height: 24),

                    // ══════════════════════════════════
                    // User Leaderboard
                    // ══════════════════════════════════
                    _buildSectionTitle(
                        'Student / Staff Leaderboard', Icons.leaderboard),
                    const SizedBox(height: 12),
                    _buildLeaderboard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────
  //  KPI CARDS
  // ─────────────────────────────────────────────
  Widget _buildKpiRow() {
    final double? emissionDelta =
        _prevPeriodEmission > 0 && _selectedPeriod != 'All Time'
            ? ((_totalCampusEmission - _prevPeriodEmission) /
                _prevPeriodEmission *
                100)
            : null;

    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            'Total CO₂',
            '${_formatNumber(_totalCampusEmission)} kg',
            Icons.cloud_outlined,
            const Color(0xFF115925),
            trendDelta: emissionDelta,
            trendHigherIsBad: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'Users',
            '$_activeUsers',
            Icons.people_outline,
            const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'Reduction',
            '${_reductionPercent != 0 ? _reductionPercent.toStringAsFixed(1) : '--'}%',
            Icons.trending_down,
            _reductionPercent >= 5
                ? const Color(0xFF115925)
                : _reductionPercent >= 0
                    ? const Color(0xFFF9A825)
                    : Colors.red.shade700,
            subtitle: _selectedPeriod == 'This Year' ? 'vs last yr' : 'vs last mth',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'Goal',
            '${_targetPercent.toStringAsFixed(0)}%',
            Icons.track_changes,
            const Color(0xFFE65100),
            subtitle: 'of 15% target',
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    double? trendDelta,
    bool trendHigherIsBad = false,
    String? subtitle,
  }) {
    Widget? trendWidget;
    if (trendDelta != null) {
      final isUp = trendDelta > 0;
      final isBad = trendHigherIsBad ? isUp : !isUp;
      trendWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: isBad ? Colors.red[400] : Colors.green[600],
          ),
          const SizedBox(width: 1),
          Text(
            '${trendDelta.abs().toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isBad ? Colors.red[400] : Colors.green[600],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: color.withOpacity(0.7)),
            ),
          if (trendWidget != null) ...[const SizedBox(height: 2), trendWidget],
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SECTION TITLE
  // ─────────────────────────────────────────────
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  EMISSION TREND LINE CHART
  // ─────────────────────────────────────────────
  Widget _buildTrendChart() {
    if (_trendData.isEmpty) {
      return _emptyWidget('No emission data yet', Icons.show_chart);
    }

    final rawMax = _trendData.map((e) => e.value).reduce(max);
    final maxY = rawMax > 0 ? rawMax * 1.15 : 1.0;
    final hInterval = maxY / 4;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: hInterval > 0 ? hInterval : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatNumber(value),
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _trendData.length) {
                    return const SizedBox.shrink();
                  }
                  // Show every label or every other for space
                  if (_trendData.length > 6 && idx % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  // Convert full month name to abbreviated for chart axis
                  final rawLabel = _trendData[idx].label.split(' ').first;
                  final monthIdx = _monthIndex(rawLabel);
                  final label = monthIdx > 0
                      ? _monthAbbrFromInt(monthIdx)
                      : rawLabel.substring(0, rawLabel.length.clamp(0, 3));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style:
                          TextStyle(fontSize: 9, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(_trendData.length, (i) {
                return FlSpot(i.toDouble(), _trendData[i].value);
              }),
              isCurved: true,
              curveSmoothness: 0.3,
              color: _primary,
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    _primary.withOpacity(0.3),
                    _primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: _primary,
                  );
                },
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final label =
                      idx < _trendData.length ? _trendData[idx].label : '';
                  return LineTooltipItem(
                    '$label\n${spot.y.toStringAsFixed(1)} kg CO₂e',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EMISSIONS BY FACILITY TYPE — PIE CHART
  // ─────────────────────────────────────────────
  Widget _buildPieChart() {
    if (_facilityEmissions.isEmpty) {
      return _emptyWidget('No data', Icons.pie_chart);
    }

    final colors = [
      const Color(0xFF115925),
      const Color(0xFF1565C0),
      const Color(0xFFE65100),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
      const Color(0xFF0277BD),
      const Color(0xFF888888),
    ];

    final entries = _facilityEmissions.entries.toList();
    final totalFacility =
        entries.fold(0.0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'By Facility Type',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: List.generate(entries.length, (i) {
                  final pct = totalFacility > 0
                      ? (entries[i].value / totalFacility * 100)
                      : 0.0;
                  return PieChartSectionData(
                    value: entries[i].value,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    color: colors[i % colors.length],
                    radius: 32,
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend
          ...List.generate(entries.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entries[i].key,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
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

  // ─────────────────────────────────────────────
  //  TOP 5 HIGH-EMISSION ZONES
  // ─────────────────────────────────────────────
  Widget _buildTopZones() {
    if (_topZones.isEmpty) {
      return _emptyWidget('No data', Icons.bar_chart);
    }

    final maxVal = _topZones.first.value;
    final zoneColors = [
      const Color(0xFF115925),
      const Color(0xFF1E8449),
      const Color(0xFF27AE60),
      const Color(0xFF52BE80),
      const Color(0xFF82E0AA),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 High-Emission Zones',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_topZones.length, (i) {
            final zone = _topZones[i];
            final ratio = maxVal > 0 ? zone.value / maxVal : 0.0;
            return GestureDetector(
              onTap: () => _showBuildingDrillDown(zone.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            zone.key,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF555555)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 14, color: Color(0xFFAAAAAA)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 14,
                              backgroundColor: Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation(
                                  zoneColors[i % zoneColors.length]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatNumber(zone.value),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  TREES GAUGE / IMPACT CARD
  // ─────────────────────────────────────────────
  Widget _buildTreesGauge() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campus Impact',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Total campus emissions of ${_formatNumber(_totalCampusEmission)} kg CO₂e '
                  'would require $_totalTreesNeeded trees to offset annually.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniStat('$_activeUsers', 'Active\nUsers'),
                    const SizedBox(width: 16),
                    _miniStat('$_totalProfiles', 'Total\nProfiles'),
                    const SizedBox(width: 16),
                    _miniStat(
                        '${_campusRecords.length}', 'Campus\nRecords'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Tree circle gauge
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _TreeGaugePainter(
                trees: _totalTreesNeeded,
                progress: (_targetPercent / 100).clamp(0, 1),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatNumber(_totalTreesNeeded.toDouble()),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    const Text(
                      'Trees\nNeeded',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _primary,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  PERIOD FILTER AGGREGATION
  // ─────────────────────────────────────────────
  void _applyPeriodFilter(String period, {bool isInitialLoad = false}) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    bool matchesPeriod(Map<String, dynamic> r, String p) {
      final year = r['year'] as int? ?? 0;
      final monthStr = r['month'] as String? ?? '';
      final monthIdx = _monthIndex(monthStr);
      switch (p) {
        case 'This Month':
          return year == currentYear && monthIdx == currentMonth;
        case 'This Year':
          return year == currentYear;
        case 'Custom':
          if (_selectedCustomMonth != null) {
            return year == _selectedCustomMonth!.year &&
                monthIdx == _selectedCustomMonth!.month;
          }
          return false;
        default:
          return true; // 'All Time'
      }
    }

    // Baseline = same period one year prior (for reduction % calculation)
    double baselineEmission = 0.0;
    double prevEmission = 0.0;
    if (period != 'All Time') {
      for (final r in _campusRecords) {
        final year = r['year'] as int? ?? 0;
        final monthStr = r['month'] as String? ?? '';
        final monthIdx = _monthIndex(monthStr);
        bool isPrev = false;
        bool isBaseline = false;
        switch (period) {
          case 'This Month':
            // Compare current month vs previous month
            final pm = currentMonth == 1 ? 12 : currentMonth - 1;
            final py = currentMonth == 1 ? currentYear - 1 : currentYear;
            isPrev = year == py && monthIdx == pm;
            isBaseline = isPrev;
            break;
          case 'This Year':
            // Compare this full year vs last full year
            isPrev = year == currentYear - 1;
            isBaseline = year == currentYear - 1;
            break;
          case 'Custom':
            // Compare selected month vs the month before it
            if (_selectedCustomMonth != null) {
              final cm = _selectedCustomMonth!.month;
              final cy = _selectedCustomMonth!.year;
              final bm = cm == 1 ? 12 : cm - 1;
              final by = cm == 1 ? cy - 1 : cy;
              isPrev = year == by && monthIdx == bm;
              isBaseline = isPrev;
            }
            break;
        }
        final val = (r['emission_value'] as num?)?.toDouble() ?? 0.0;
        if (isPrev) prevEmission += val;
        if (isBaseline) baselineEmission += val;
      }
    }

    final filtered = period == 'All Time'
        ? _campusRecords
        : _campusRecords.where((r) => matchesPeriod(r, period)).toList();

    double totalEmission = 0.0;
    final facilityMap = <String, double>{};
    final buildingMap = <String, double>{};
    final monthlyMap = <String, double>{};

    for (final r in filtered) {
      final emission = (r['emission_value'] as num?)?.toDouble() ?? 0.0;
      final category = r['category'] as String? ?? 'Other';
      final building = r['building_name'] as String? ?? 'Unknown';
      final month = r['month'] as String? ?? '';
      final year = r['year'] as int? ?? 0;
      totalEmission += emission;
      facilityMap[category] = (facilityMap[category] ?? 0) + emission;
      buildingMap[building] = (buildingMap[building] ?? 0) + emission;
      if (month.isNotEmpty && year > 0) {
        final key = '$month $year';
        monthlyMap[key] = (monthlyMap[key] ?? 0) + emission;
      }
    }

    final sortedMonths = monthlyMap.entries.toList()
      ..sort((a, b) {
        final aParts = a.key.split(' ');
        final bParts = b.key.split(' ');
        final aYear = int.tryParse(aParts.length > 1 ? aParts[1] : '') ?? 0;
        final bYear = int.tryParse(bParts.length > 1 ? bParts[1] : '') ?? 0;
        if (aYear != bYear) return aYear.compareTo(bYear);
        return _monthOrder
            .indexOf(aParts[0])
            .compareTo(_monthOrder.indexOf(bParts[0]));
      });

    double cumulative = 0;
    final trendPoints = <_TrendPoint>[];
    for (final entry in sortedMonths) {
      cumulative += entry.value;
      trendPoints.add(_TrendPoint(entry.key, cumulative));
    }

    final sortedBuildings = buildingMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedBuildings.take(5).toList();

    // Reduction % vs same period last year (positive = good, negative = worse)
    final reductionPct = baselineEmission > 0
        ? ((baselineEmission - totalEmission) / baselineEmission * 100)
            .clamp(-100.0, 100.0)
        : 0.0;

    // Target progress: how close we are to _targetReduction% goal
    final progress = baselineEmission > 0
        ? (reductionPct / _targetReduction * 100).clamp(0.0, 100.0)
        : 0.0;

    final grade = _computeHealthGrade(reductionPct);
    final trees = totalEmission > 0 ? (totalEmission / 21.77).ceil() : 0;

    if (mounted) {
      setState(() {
        _selectedPeriod = period;
        _totalCampusEmission = totalEmission;
        _prevPeriodEmission = prevEmission;
        _targetPercent = progress;
        _facilityEmissions = facilityMap;
        _trendData = trendPoints;
        _topZones = top5;
        _totalTreesNeeded = trees;
        _healthGrade = grade;
        _reductionPercent = reductionPct;
        if (isInitialLoad) _isLoading = false;
      });
    }
  }

  /// Grade is based on reduction % vs same period last year.
  /// Positive = emissions went down (good). Negative = emissions went up.
  String _computeHealthGrade(double reductionPct) {
    if (reductionPct == 0) return 'N/A';
    if (reductionPct >= 15) return 'A+';
    if (reductionPct >= 10) return 'A';
    if (reductionPct >= 5) return 'B';
    if (reductionPct >= 0) return 'C';
    return 'F'; // Emissions increased vs last year
  }

  Color _gradeColor(String grade) {
    if (grade.startsWith('A')) return const Color(0xFF115925);
    if (grade.startsWith('B')) return const Color(0xFF1565C0);
    if (grade.startsWith('C')) return const Color(0xFFF9A825);
    if (grade.startsWith('D')) return const Color(0xFFE65100);
    if (grade == 'F') return Colors.red[700]!;
    return Colors.grey;
  }

  // ─────────────────────────────────────────────
  //  PDF HELPERS
  // ─────────────────────────────────────────────
  /// Strips characters that Helvetica (the default PDF font) cannot render,
  /// including all emojis and non-ASCII symbols.  Common symbols are first
  /// replaced with their closest ASCII equivalents.
  String _sanitizePdfText(String text) {
    return text
        .replaceAll('\u2014', '-')   // em dash
        .replaceAll('\u2013', '-')   // en dash
        .replaceAll('\u2018', "'")   // left single quote
        .replaceAll('\u2019', "'")   // right single quote
        .replaceAll('\u201C', '"')   // left double quote
        .replaceAll('\u201D', '"')   // right double quote
        .replaceAll('\u2022', '*')   // bullet
        .replaceAll('\u00B7', '*')   // middle dot (bullet)
        .replaceAll('\u2026', '...') // ellipsis
        .replaceAll('\u00B0', ' degrees') // degree sign
        .replaceAll('\u2082', '2')   // subscript 2 (CO2)
        .replaceAll('\u2192', '->')  // right arrow
        .replaceAll('\u00e9', 'e')   // é
        .replaceAll('\u00e8', 'e')   // è
        .replaceAll('\u00e0', 'a')   // à
        // Strip any remaining non-ASCII (emojis, Hangul, CJK, etc.)
        .replaceAllMapped(
          RegExp(r'[^\x00-\x7F]'),
          (_) => '',
        )
        .trim();
  }

  // ─────────────────────────────────────────────
  //  EXPORT PDF REPORT
  // ─────────────────────────────────────────────
  Future<void> _exportReport() async {
    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = '${_monthOrder[now.month - 1]} ${now.day}, ${now.year}';
    const pdfGreen = PdfColor(0.067, 0.349, 0.145);
    const pdfBlue = PdfColor(0.082, 0.396, 0.753);
    const pdfOrange = PdfColor(0.902, 0.318, 0.000);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context ctx) => [
          // ── Header ──
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: pdfGreen,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'UTP Campus Carbon Emission Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated: $dateStr  |  Period: $_selectedPeriod',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          // ── KPIs ──
          pw.Text('Key Performance Indicators',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Metric', 'Value'],
            data: [
              ['Total CO2 Recorded', '${_totalCampusEmission.toStringAsFixed(1)} kg CO2e'],
              ['Active Tracked Users', '$_activeUsers'],
              ['CO2 Reduction vs Prior Period', '${_reductionPercent.toStringAsFixed(1)}%'],
              ['Campus Health Grade', _healthGrade],
              ['Goal Progress (15% target)', '${_targetPercent.toStringAsFixed(1)}%'],
              ['Trees Needed to Offset', '$_totalTreesNeeded trees/year'],
              ['Total Records', '${_campusRecords.length}'],
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: pdfGreen),
            cellHeight: 22,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 20),
          // ── Top Zones ──
          if (_topZones.isNotEmpty) ...[
            pw.Text('Top High-Emission Zones',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['#', 'Building / Zone', 'CO2e (kg)'],
              data: _topZones
                  .asMap()
                  .entries
                  .map((e) => [
                        '${e.key + 1}',
                        e.value.key,
                        _formatNumber(e.value.value),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: pdfBlue),
              cellHeight: 22,
            ),
            pw.SizedBox(height: 20),
          ],
          // ── Facility Type ──
          if (_facilityEmissions.isNotEmpty) ...[
            pw.Text('Emissions by Facility Type',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Facility Type', 'CO2e (kg)', 'Share'],
              data: () {
                final total =
                    _facilityEmissions.values.fold(0.0, (s, v) => s + v);
                return _facilityEmissions.entries
                    .map((e) => [
                          e.key,
                          _formatNumber(e.value),
                          '${(e.value / total * 100).toStringAsFixed(1)}%',
                        ])
                    .toList();
              }(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: pdfOrange),
              cellHeight: 22,
            ),
            pw.SizedBox(height: 20),
          ],
          // ── AI Recommendations ──
          if (_aiSuggestion != null) ...[
            pw.Text('AI Campus Recommendations',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pdfGreen),
                borderRadius: pw.BorderRadius.circular(4),
                color: PdfColors.green50,
              ),
              child: pw.Text(
                _sanitizePdfText(_aiSuggestion!),
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.SizedBox(height: 20),
          ],
          // ── Footer ──
          pw.Divider(),
          pw.Text(
            'CarbonLit - UTP Carbon Management System  |  $dateStr',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'UTP_Carbon_Report_${_selectedPeriod.replaceAll(' ', '_')}.pdf',
    );
  }

  // ─────────────────────────────────────────────
  //  BUILDING DRILL-DOWN BOTTOM SHEET
  // ─────────────────────────────────────────────
  void _showBuildingDrillDown(String building) {
    final records = _campusRecords
        .where((r) => (r['building_name'] as String? ?? '') == building)
        .toList();

    final monthlyMap = <String, double>{};
    final categories = <String, double>{};
    double total = 0;

    for (final r in records) {
      final emission = (r['emission_value'] as num?)?.toDouble() ?? 0.0;
      final month = r['month'] as String? ?? '';
      final year = r['year'] as int? ?? 0;
      final cat = r['category'] as String? ?? 'Other';
      total += emission;
      categories[cat] = (categories[cat] ?? 0) + emission;
      if (month.isNotEmpty && year > 0) {
        final key = '$month $year';
        monthlyMap[key] = (monthlyMap[key] ?? 0) + emission;
      }
    }

    final sortedMonths = monthlyMap.entries.toList()
      ..sort((a, b) {
        final aParts = a.key.split(' ');
        final bParts = b.key.split(' ');
        final aYear = int.tryParse(aParts.length > 1 ? aParts[1] : '') ?? 0;
        final bYear = int.tryParse(bParts.length > 1 ? bParts[1] : '') ?? 0;
        if (aYear != bYear) return aYear.compareTo(bYear);
        return _monthOrder
            .indexOf(aParts[0])
            .compareTo(_monthOrder.indexOf(bParts[0]));
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.business,
                        color: Color(0xFF115925), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        building,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_formatNumber(total)} kg total',
                        style: const TextStyle(
                          color: Color(0xFF115925),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text('By Facility Category',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF333333))),
                    const SizedBox(height: 10),
                    ...categories.entries.map((e) {
                      final ratio = total > 0 ? e.value / total : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(e.key,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF555555)))),
                              Text('${_formatNumber(e.value)} kg',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF115925)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (sortedMonths.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Monthly Breakdown',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF333333))),
                      const SizedBox(height: 10),
                      ...sortedMonths.map((e) {
                        final ratio = total > 0 ? e.value / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(e.key,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF555555)))),
                                Text('${_formatNumber(e.value)} kg',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF1E8449)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  CAMPUS HEALTH SCORE BANNER
  // ─────────────────────────────────────────────
  Widget _buildHealthScoreBanner() {
    final gradeColor = _gradeColor(_healthGrade);
    final now = DateTime.now();
    final dateStr = '${_monthOrder[now.month - 1]} ${now.day}, ${now.year}';

    String trendText = '';
    Color trendColor = Colors.white60;
    IconData trendIcon = Icons.remove;
    if (_selectedPeriod != 'All Time' && _prevPeriodEmission > 0) {
      final diff = _totalCampusEmission - _prevPeriodEmission;
      final pct = diff.abs() / _prevPeriodEmission * 100;
      trendText =
          '${diff > 0 ? '↑' : '↓'} ${pct.toStringAsFixed(0)}% vs previous period';
      trendColor = diff > 0 ? Colors.redAccent.shade100 : Colors.greenAccent.shade100;
      trendIcon = diff > 0 ? Icons.trending_up : Icons.trending_down;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3318), Color(0xFF115925), Color(0xFF1B7A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF115925).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'UTP \u00b7 CarbonLit Analytics',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Campus Carbon\nHealth Score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    if (_reductionPercent != 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_reductionPercent >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          () {
                            final label = _selectedPeriod == 'This Year'
                                ? 'vs last year'
                                : 'vs last month';
                            return _reductionPercent >= 0
                                ? '↓ ${_reductionPercent.toStringAsFixed(1)}% $label'
                                : '↑ ${_reductionPercent.abs().toStringAsFixed(1)}% increase $label';
                          }(),
                          style: TextStyle(
                            color: _reductionPercent >= 0
                                ? Colors.greenAccent.shade100
                                : Colors.redAccent.shade100,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (trendText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(trendIcon, color: trendColor, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            trendText,
                            style: TextStyle(
                              color: trendColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: grade circle
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradeColor.withOpacity(0.15),
                  border:
                      Border.all(color: gradeColor.withOpacity(0.9), width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: gradeColor.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _healthGrade,
                        style: TextStyle(
                          color: _healthGrade == 'N/A'
                              ? Colors.white54
                              : Colors.white,
                          fontSize: _healthGrade.length > 2 ? 22 : 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Grade',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom stats bar
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bannerStat('${_formatNumber(_totalCampusEmission)} kg', 'Total CO\u2082'),
                Container(width: 1, height: 28, color: Colors.white24),
                _bannerStat(
                  _reductionPercent != 0
                      ? '${_reductionPercent.toStringAsFixed(1)}%'
                      : '--',
                  'Reduction',
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                _bannerStat('${_campusRecords.length}', 'Records'),
                Container(width: 1, height: 28, color: Colors.white24),
                _bannerStat('$_activeUsers', 'Active Users'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  PERIOD FILTER CHIPS
  // ─────────────────────────────────────────────
  Widget _buildPeriodFilter() {
    const periods = ['All Time', 'This Year', 'This Month'];
    final isCustomSelected = _selectedPeriod == 'Custom';
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...List.generate(periods.length, (i) {
            final p = periods[i];
            final isSelected = _selectedPeriod == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedCustomMonth = null);
                  _applyPeriodFilter(p);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _primary : Colors.grey.shade300,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primary.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF555555),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
          // ── Calendar / Pick Month button ──
          GestureDetector(
            onTap: _pickMonth,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCustomSelected ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCustomSelected ? _primary : Colors.grey.shade300,
                ),
                boxShadow: isCustomSelected
                    ? [
                        BoxShadow(
                          color: _primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 15,
                    color: isCustomSelected
                        ? Colors.white
                        : const Color(0xFF555555),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isCustomSelected && _selectedCustomMonth != null
                        ? '${_monthAbbrFromInt(_selectedCustomMonth!.month)} ${_selectedCustomMonth!.year}'
                        : 'Pick Month',
                    style: TextStyle(
                      color: isCustomSelected
                          ? Colors.white
                          : const Color(0xFF555555),
                      fontWeight: isCustomSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _selectedCustomMonth ?? DateTime(now.year, now.month);

    // Month-year picker dialog
    int pickerYear = initial.year;
    int pickerMonth = initial.month;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Select Month',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () =>
                            setDialogState(() => pickerYear--),
                      ),
                      Text(
                        '$pickerYear',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () =>
                            setDialogState(() => pickerYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Month grid — fixed height to avoid unbounded layout error
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.6,
                    children: List.generate(12, (i) {
                      final isSelected = pickerMonth == i + 1;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => pickerMonth = i + 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _primary
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _monthOrder[i],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF333333),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(
                    ctx, DateTime(pickerYear, pickerMonth)),
                child: const Text('Apply'),
              ),
            ],
          );
        });
      },
    );

    if (picked != null) {
      setState(() => _selectedCustomMonth = picked);
      _applyPeriodFilter('Custom');
    }
  }

  // ─────────────────────────────────────────────
  //  CAMPUS AI SUGGESTION
  // ─────────────────────────────────────────────
  Future<void> _fetchCampusAI() async {
    if (mounted) setState(() => _loadingSuggestion = true);

    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty || _totalCampusEmission == 0) {
      if (mounted) {
        setState(() {
          _aiSuggestion = _totalCampusEmission == 0
              ? 'No campus emission data recorded yet. Add records to get AI insights.'
              : 'API key not configured. Add OPENAI_API_KEY to .env file.';
          _loadingSuggestion = false;
        });
      }
      return;
    }

    // Top facility type
    final topFacility = _facilityEmissions.entries.isEmpty
        ? 'Unknown'
        : (_facilityEmissions.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    final topZone = _topZones.isEmpty ? 'Unknown' : _topZones.first.key;

    const models = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemini-2.0-flash-exp:free',
      'mistralai/mistral-7b-instruct:free',
      'qwen/qwen2.5-7b-instruct:free',
    ];

    const systemPrompt =
        'You are a sustainability advisor for a university campus carbon management app called CarbonLit. '
        'Give exactly 3 short, actionable recommendations (max 1 sentence each) for the campus admin to reduce overall campus carbon emissions. '
        'Use one relevant emoji at the start of each tip. Be specific to the data provided. '
        'IMPORTANT: Do NOT use any markdown formatting. No bold, no asterisks, no hashtags, no numbered lists, no dashes. '
        'Output plain text only. Separate each tip with a blank line.';

    final userPrompt =
        'Campus carbon footprint summary:\n'
        '- Total campus emission: ${_totalCampusEmission.toStringAsFixed(1)} kg CO₂e\n'
        '- Active tracked users: $_activeUsers\n'
        '- Highest-emission facility type: $topFacility\n'
        '- Highest-emission building/zone: $topZone\n'
        '- Trees needed to offset: $_totalTreesNeeded\n\n'
        'Give 3 campus-level recommendations to reduce emissions.';

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://carbonlit.app',
            'X-Title': 'CarbonLit',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'max_tokens': 300,
            'temperature': 0.7,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content =
              data['choices']?[0]?['message']?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            if (mounted) {
              setState(() {
                _aiSuggestion = content.trim();
                _loadingSuggestion = false;
              });
            }
            return;
          }
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          debugPrint('Model $model rate-limited, trying next...');
          continue;
        } else {
          debugPrint('Model $model error: ${response.statusCode}');
          continue;
        }
      } catch (e) {
        debugPrint('Model $model exception: $e');
        continue;
      }
    }

    // All failed — local fallback
    if (mounted) {
      setState(() {
        _aiSuggestion =
            '🌿 Focus on reducing energy use in the highest-emission building ($topZone).\n\n'
            '☀️ Consider renewable energy installations for the $topFacility facility type.\n\n'
            '🚌 Promote carpooling and public transport to reduce user-level transport emissions.';
        _loadingSuggestion = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  //  AI SUGGESTION CARD WIDGET
  // ─────────────────────────────────────────────
  Widget _buildAICard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F5E9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFF115925), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Campus Recommendations',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _fetchCampusAI,
                child: Icon(Icons.refresh, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingSuggestion)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF115925),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Getting AI insights...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              ],
            )
          else
            Text(
              _aiSuggestion ?? 'Tap refresh to get AI recommendations.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF444444),
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  USER LEADERBOARD
  // ─────────────────────────────────────────────
  Widget _buildLeaderboard() {
    if (_leaderboardData.isEmpty) {
      return _emptyWidget('No tracked users yet', Icons.leaderboard);
    }

    final medalColors = [
      const Color(0xFFFFD700), // gold
      const Color(0xFFB0BEC5), // silver
      const Color(0xFFCD7F32), // bronze
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.bold))),
                const Expanded(child: Text('Name', style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.bold))),
                const Text('Role', style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Text('kg CO₂e', style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _leaderboardData.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, i) {
              final user = _leaderboardData[i];
              final rank = i + 1;
              final emission = user['total'] as double;
              final role = (user['role'] as String? ?? 'student').toLowerCase();
              final isMedal = rank <= 3;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Rank
                    SizedBox(
                      width: 32,
                      child: isMedal
                          ? Icon(Icons.circle, color: medalColors[rank - 1], size: 22)
                          : Text(
                              '$rank',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF555555),
                              ),
                            ),
                    ),
                    // Name
                    Expanded(
                      child: Text(
                        user['name'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: role == 'admin'
                            ? const Color(0xFFE3F2FD)
                            : role == 'staff'
                                ? const Color(0xFFFFF3E0)
                                : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _capitalize(role),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: role == 'admin'
                              ? const Color(0xFF1565C0)
                              : role == 'staff'
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF115925),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Emission value
                    Text(
                      _formatNumber(emission),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────
  Widget _emptyWidget(String text, IconData icon) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class _TrendPoint {
  final String label;
  final double value;
  const _TrendPoint(this.label, this.value);
}

// ─────────────────────────────────────────────
//  TREE GAUGE PAINTER
// ─────────────────────────────────────────────
class _TreeGaugePainter extends CustomPainter {
  final int trees;
  final double progress;

  _TreeGaugePainter({required this.trees, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFE8F5E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    // Foreground arc
    final fgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF115925), Color(0xFF27AE60)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      pi * 1.5 * progress.clamp(0, 1),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TreeGaugePainter old) =>
      old.trees != trees || old.progress != progress;
}
