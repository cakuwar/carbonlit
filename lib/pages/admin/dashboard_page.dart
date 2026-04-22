import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard/widgets/welcome_banner.dart';
import 'dashboard/widgets/carbon_ring.dart';
import 'dashboard/widgets/category_summary.dart';
import 'dashboard/widgets/emission_chart.dart';
import 'dashboard/widgets/goals_section.dart';
import 'dashboard/widgets/widget_selector.dart';
import 'dashboard/widgets/tree_offset_card.dart';
import 'dashboard/widgets/campus_emissions.dart';

/// Full-featured Dashboard page.
///
/// Shows carbon footprint analytics, category breakdown, weekly chart,
/// goals, tree offset, leaderboard — all customizable via a widget selector.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color _primaryGreen = Color(0xFF115925);

  // ── Toggle visibility of dashboard widgets ──
  bool _showCarbonRing = true;
  bool _showCategoryCards = true;
  bool _showChart = true;
  bool _showGoals = true;
  bool _showTreeOffset = true;
  bool _showCampusEmissions = true;

  // ── Data state ──
  bool _isLoading = true;
  String _userName = '';
  double _totalEmission = 0.0;
  double _weeklyEmission = 0.0; // always last-7-days, used for weekly goal
  int _streakDays = 0;
  int _treesOffset = 0;
  Map<String, double> _categoryEmissions = {
    'Transportation': 0.0,
    'Gadgets': 0.0,
    'Accommodation': 0.0,
  };
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _campusRecords = [];
  final double _goalTarget = 50.0; // kg CO₂e/week goal

  // ── Raw records for period filtering ──
  List<Map<String, dynamic>> _rawTransportRecords = [];
  List<Map<String, dynamic>> _rawGadgetRecords = [];
  List<Map<String, dynamic>> _rawAccomRecords = [];

  // ── Time filter ──
  String _selectedPeriod = 'This Week';
  DateTime? _pickedDate; // set when user picks a specific date
  final List<String> _periods = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'This Year',
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ── Load user profile ──
      final profile = await supabase
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        _userName =
            '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                .trim();
      }

      // ── Load transport records (current user) ──
      List<Map<String, dynamic>> transportRecords = [];
      try {
        transportRecords = await supabase
            .from('transport_records')
            .select('daily_emission, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      } catch (_) {
        // Table may not exist yet
      }

      // ── Load gadget records (current user) ──
      List<Map<String, dynamic>> gadgetRecords = [];
      try {
        gadgetRecords = await supabase
            .from('gadget_records')
            .select('daily_emission, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      } catch (_) {}

      // ── Load accommodation records (current user) ──
      List<Map<String, dynamic>> accomRecords = [];
      try {
        accomRecords = await supabase
            .from('accommodation_records')
            .select('daily_emission, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      } catch (_) {}

      // ── Load campus emission records (admin-entered) ──
      List<Map<String, dynamic>> campusRecords = [];
      try {
        campusRecords = await supabase
            .from('emission_records')
            .select('building_name, category, month, year, energy_consumed, emission_value, created_at')
            .order('created_at', ascending: false);
      } catch (_) {}

      // ── Streak (consecutive days with records) ──
      final now = DateTime.now();
      final allRecordDates = <Map<String, dynamic>>[
        ...transportRecords,
        ...gadgetRecords,
        ...accomRecords,
      ];

      int streak = 0;
      for (int i = 0; i < 365; i++) {
        final day = now.subtract(Duration(days: i));
        bool hasRecord = false;
        for (final r in allRecordDates) {
          final createdAt = DateTime.tryParse(r['created_at'] ?? '');
          if (createdAt != null &&
              createdAt.year == day.year &&
              createdAt.month == day.month &&
              createdAt.day == day.day) {
            hasRecord = true;
            break;
          }
        }
        if (hasRecord) {
          streak++;
        } else {
          break;
        }
      }

      if (mounted) {
        setState(() {
          _rawTransportRecords = transportRecords;
          _rawGadgetRecords = gadgetRecords;
          _rawAccomRecords = accomRecords;
          _streakDays = streak;
          _campusRecords = campusRecords;
          _isLoading = false;
        });
        _applyPeriodFilter();
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyPeriodFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    bool inPeriod(DateTime date) {
      final d = DateTime(date.year, date.month, date.day);
      switch (_selectedPeriod) {
        case 'Today':
          return d == today;
        case 'Yesterday':
          return d == yesterday;
        case 'This Week':
          return !d.isBefore(today.subtract(const Duration(days: 6)));
        case 'This Month':
          return d.year == today.year && d.month == today.month;
        case 'This Year':
          return d.year == today.year;
        case 'Custom':
          if (_pickedDate == null) return true;
          final picked = DateTime(
              _pickedDate!.year, _pickedDate!.month, _pickedDate!.day);
          return d == picked;
        default:
          return true;
      }
    }

    double transportTotal = 0.0;
    double gadgetTotal = 0.0;
    double accomTotal = 0.0;

    for (final r in _rawTransportRecords) {
      final createdAt = DateTime.tryParse(r['created_at'] ?? '');
      if (createdAt != null && inPeriod(createdAt)) {
        transportTotal += (r['daily_emission'] as num?)?.toDouble() ?? 0.0;
      }
    }
    for (final r in _rawGadgetRecords) {
      final createdAt = DateTime.tryParse(r['created_at'] ?? '');
      if (createdAt != null && inPeriod(createdAt)) {
        gadgetTotal += (r['daily_emission'] as num?)?.toDouble() ?? 0.0;
      }
    }
    for (final r in _rawAccomRecords) {
      final createdAt = DateTime.tryParse(r['created_at'] ?? '');
      if (createdAt != null && inPeriod(createdAt)) {
        accomTotal += (r['daily_emission'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final totalAll = transportTotal + gadgetTotal + accomTotal;
    final trees = totalAll > 0 ? (totalAll * 365 / 21.77).ceil() : 0;

    // Weekly chart: always show last 7 days as trend context
    final allRecords = [
      ..._rawTransportRecords,
      ..._rawGadgetRecords,
      ..._rawAccomRecords,
    ];
    final List<Map<String, dynamic>> weekly = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStr = '${day.month}/${day.day}';
      double dayTotal = 0.0;
      for (final r in allRecords) {
        final createdAt = DateTime.tryParse(r['created_at'] ?? '');
        if (createdAt != null &&
            createdAt.year == day.year &&
            createdAt.month == day.month &&
            createdAt.day == day.day) {
          dayTotal += (r['daily_emission'] as num?)?.toDouble() ?? 0.0;
        }
      }
      weekly.add({'day': dayStr, 'emission': dayTotal});
    }

    final weeklyTotal =
        weekly.fold<double>(0.0, (sum, e) => sum + (e['emission'] as double));

    if (mounted) {
      setState(() {
        _totalEmission = totalAll;
        _weeklyEmission = weeklyTotal;
        _categoryEmissions = {
          'Transportation': transportTotal,
          'Gadgets': gadgetTotal,
          'Accommodation': accomTotal,
        };
        _weeklyData = weekly;
        _treesOffset = trees;
      });
    }
  }

  Future<void> _openDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Select a date to view emissions',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF115925),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _pickedDate = picked;
        _selectedPeriod = 'Custom';
      });
      _applyPeriodFilter();
    }
  }

  void _openWidgetSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => WidgetSelector(
        showCarbonRing: _showCarbonRing,
        showCategoryCards: _showCategoryCards,
        showChart: _showChart,
        showGoals: _showGoals,
        showTreeOffset: _showTreeOffset,
        showCampusEmissions: _showCampusEmissions,
        onChanged: (key, value) {
          setState(() {
            switch (key) {
              case 'carbonRing':
                _showCarbonRing = value;
                break;
              case 'categoryCards':
                _showCategoryCards = value;
                break;
              case 'chart':
                _showChart = value;
                break;
              case 'goals':
                _showGoals = value;
                break;
              case 'treeOffset':
                _showTreeOffset = value;
                break;
              case 'campusEmissions':
                _showCampusEmissions = value;
                break;
            }
          });
          Navigator.pop(ctx);
          _openWidgetSelector(); // Reopen to reflect changes
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(color: _primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        color: _primaryGreen,
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Banner ──
              WelcomeBanner(
                userName: _userName,
                streakDays: _streakDays,
              ),
              const SizedBox(height: 20),

              // ── Period Filter + Customize button ──
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _periods.length +
                            (_selectedPeriod == 'Custom' ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          // Custom chip shown at the end when active
                          if (i == _periods.length) {
                            final label =
                                '${_pickedDate!.month}/${_pickedDate!.day}/${_pickedDate!.year}';
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPeriod = 'Custom';
                                });
                                _applyPeriodFilter();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _primaryGreen,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _primaryGreen),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 12,
                                        color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _pickedDate = null;
                                          _selectedPeriod =
                                              'This Week';
                                        });
                                        _applyPeriodFilter();
                                      },
                                      child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final isSelected =
                              _periods[i] == _selectedPeriod;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPeriod = _periods[i];
                                _pickedDate = null;
                              });
                              _applyPeriodFilter();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _primaryGreen
                                    : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? _primaryGreen
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                _periods[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── Calendar (pick date) button ──
                  GestureDetector(
                    onTap: _openDatePicker,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedPeriod == 'Custom'
                            ? _primaryGreen
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _selectedPeriod == 'Custom'
                                ? _primaryGreen
                                : Colors.grey.shade300),
                      ),
                      child: Icon(Icons.calendar_month,
                          size: 20,
                          color: _selectedPeriod == 'Custom'
                              ? Colors.white
                              : _primaryGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _openWidgetSelector,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.tune,
                          size: 20, color: _primaryGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Carbon Ring ──
              if (_showCarbonRing)
                CarbonRing(
                  totalEmission: _totalEmission,
                  categoryEmissions: _categoryEmissions,
                ),
              if (_showCarbonRing) const SizedBox(height: 20),

              // ── Category Summary Cards ──
              if (_showCategoryCards)
                CategorySummary(
                    categoryEmissions: _categoryEmissions),
              if (_showCategoryCards) const SizedBox(height: 20),

              // ── Emission Chart ──
              if (_showChart)
                EmissionChart(weeklyData: _weeklyData),
              if (_showChart) const SizedBox(height: 20),

              // ── Goals Section ──
              if (_showGoals)
                GoalsSection(
                  totalEmission: _weeklyEmission,
                  goalTarget: _goalTarget,
                ),
              if (_showGoals) const SizedBox(height: 20),

              // ── Tree Offset Card ──
              if (_showTreeOffset)
                TreeOffsetCard(treesOffset: _treesOffset),
              if (_showTreeOffset) const SizedBox(height: 20),

              // ── Campus Emissions ──
              if (_showCampusEmissions)
                CampusEmissions(records: _campusRecords),
              if (_showCampusEmissions) const SizedBox(height: 20),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
