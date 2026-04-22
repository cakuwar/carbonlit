import 'dart:convert';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class PersonalPage extends StatefulWidget {
  const PersonalPage({super.key});

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  final _supabase = Supabase.instance.client;

  // Live data from Supabase
  double transportation = 0.0;
  double gadgets = 0.0;
  double accommodation = 0.0;
  int totalTrees = 0;
  bool _loadingData = true;

  double get total => transportation + gadgets + accommodation;

  String? _aiSuggestion;
  bool _loadingSuggestion = true;

  @override
  void initState() {
    super.initState();
    _fetchEmissionData();
  }

  /// Fetch the logged-in user's emission totals from Supabase
  Future<void> _fetchEmissionData() async {
    setState(() => _loadingData = true);

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loadingData = false);
      return;
    }

    try {
      // Fetch all 3 categories in parallel
      final results = await Future.wait([
        _supabase
            .from('transport_records')
            .select('daily_emission, trees_to_offset')
            .eq('user_id', userId),
        _supabase
            .from('gadget_records')
            .select('daily_emission, trees_to_offset')
            .eq('user_id', userId),
        _supabase
            .from('accommodation_records')
            .select('daily_emission, trees_to_offset')
            .eq('user_id', userId),
      ]);

      double transportTotal = 0, gadgetTotal = 0, accomTotal = 0;
      int treesTotal = 0;

      for (final r in results[0]) {
        transportTotal += (r['daily_emission'] as num?)?.toDouble() ?? 0.0;
        treesTotal += (r['trees_to_offset'] as num?)?.toInt() ?? 0;
      }
      for (final r in results[1]) {
        gadgetTotal += (r['daily_emission'] as num?)?.toDouble() ?? 0.0;
        treesTotal += (r['trees_to_offset'] as num?)?.toInt() ?? 0;
      }
      for (final r in results[2]) {
        accomTotal += (r['daily_emission'] as num?)?.toDouble() ?? 0.0;
        treesTotal += (r['trees_to_offset'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          transportation = transportTotal;
          gadgets = gadgetTotal;
          accommodation = accomTotal;
          totalTrees = treesTotal;
          _loadingData = false;
        });
        // Now fetch AI suggestion with real data
        _fetchAISuggestion();
      }
    } catch (e) {
      debugPrint('Error fetching emission data: $e');
      if (mounted) setState(() => _loadingData = false);
    }
  }

  /// Fetch AI suggestion from OpenRouter API based on real emission data.
  /// Tries multiple free models in order; falls back to local tips if all fail.
  Future<void> _fetchAISuggestion() async {
    setState(() => _loadingSuggestion = true);

    if (total == 0) {
      if (mounted) {
        setState(() {
          _aiSuggestion =
              'Start logging your emissions to get personalized tips!';
          _loadingSuggestion = false;
        });
      }
      return;
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _aiSuggestion =
              'API key not configured. Please add OPENAI_API_KEY to .env file.';
          _loadingSuggestion = false;
        });
      }
      return;
    }

    // Free models tried in order — if one is rate-limited, next is tried
    const models = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemini-2.0-flash-exp:free',
      'mistralai/mistral-7b-instruct:free',
      'qwen/qwen2.5-7b-instruct:free',
    ];

    const systemPrompt =
        'You are a sustainability advisor for a university student carbon footprint app called CarbonLit. '
        'Give exactly 3 short, actionable tips (max 1 sentence each) to reduce carbon emissions. '
        'Use one relevant emoji at the start of each tip. Be specific to their data. '
        'IMPORTANT: Do NOT use any markdown formatting. No bold, no asterisks, no hashtags, no numbered lists, no dashes. '
        'Output plain text only. Separate each tip with a blank line.';

    final userPrompt =
        'Here is my daily carbon footprint breakdown:\n'
        '- Transportation: ${transportation.toStringAsFixed(2)} kg CO2/day\n'
        '- Gadgets: ${gadgets.toStringAsFixed(2)} kg CO2/day\n'
        '- Accommodation: ${accommodation.toStringAsFixed(2)} kg CO2/day\n'
        '- Total: ${total.toStringAsFixed(2)} kg CO2/day\n'
        '- Trees needed to offset annually: $totalTrees\n\n'
        'Give me 3 personalized tips to reduce my carbon footprint.';

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
            return; // success — stop trying models
          }
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          // Rate-limited or unavailable — try next model
          debugPrint('Model $model rate-limited (${response.statusCode}), trying next...');
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

    // All models failed — use local tips
    _setLocalTips();
  }

  /// Fallback local tips when API is unavailable
  void _setLocalTips() {
    final tips = <String>[];
    if (transportation > 0) {
      tips.add(
          '🚶 Your transport emission is ${transportation.toStringAsFixed(2)} kg/day. '
          'Walk or cycle for trips under 3km to reduce it.');
    }
    if (gadgets > 0) {
      tips.add(
          '📱 Your gadget emission is ${gadgets.toStringAsFixed(2)} kg/day. '
          'Extend device usage by 1 year to cut it by ~25%.');
    }
    if (accommodation > 0) {
      tips.add(
          '🏠 Your accommodation emission is ${accommodation.toStringAsFixed(2)} kg/day. '
          'Switch to LED bulbs and reduce AC by 2°C.');
    }
    if (tips.isEmpty) {
      tips.add('Start logging your emissions to get personalized tips!');
    }
    if (mounted) {
      setState(() {
        _aiSuggestion = tips.join('\n\n');
        _loadingSuggestion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final meta = authProvider.user?.userMetadata ?? {};
    final userName = meta['first_name'] ?? authProvider.user?.email ?? 'User';

    return Scaffold(
      body: Stack(
        children: [
          // ═══ LAYER 1: Forest background ═══
          SizedBox.expand(
            child: Image.asset(
              'assets/images/hutan.png',
              fit: BoxFit.cover,
            ),
          ),

          // ═══ LAYER 2: Top content (greeting + impact) ═══
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // ── Greeting Row ──
                  _GreetingSection(
                    userName: userName,
                    onSettings: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                    onHome: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // ── Impact Story Card ──
                  _ImpactCard(totalTrees: totalTrees, total: total),
                ],
              ),
            ),
          ),

          // ═══ LAYER 3: Draggable bottom sheet ═══
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.45,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: _loadingData
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: CircularProgressIndicator(
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      )
                    : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  children: [
                    // ── Drag Handle ──
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 24),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // ── 3 Emission Categories ──
                    _buildEmissionRow('Transportation', transportation),
                    const SizedBox(height: 20),
                    _buildEmissionRow('Gadgets', gadgets),
                    const SizedBox(height: 20),
                    _buildEmissionRow('Accommodation', accommodation),

                    // ── Visible when dragged UP ──
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Daily emissions chart
                    Text(
                      'Daily Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DailyChart(
                      transportation: transportation,
                      gadgets: gadgets,
                      accommodation: accommodation,
                    ),

                    const SizedBox(height: 24),

                    // AI Suggestion Card
                    _AISuggestionCard(
                      suggestion: _aiSuggestion,
                      loading: _loadingSuggestion,
                      onRefresh: _fetchAISuggestion,
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

  // ── Single emission row builder ──
  Widget _buildEmissionRow(String label, double value) {
    final progress = (value / total).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(2)} kg CO₂/day',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.grey[300],
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF1A3FC4)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  GREETING SECTION
// ─────────────────────────────────────────────
class _GreetingSection extends StatelessWidget {
  final String userName;
  final VoidCallback onSettings;
  final VoidCallback onHome;

  const _GreetingSection({
    required this.userName,
    required this.onSettings,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profile picture
        const CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white24,
          backgroundImage: AssetImage('assets/images/profile.png'),
        ),
        const SizedBox(width: 12),
        // Greeting text
        Expanded(
          child: Text(
            'Hello, $userName !',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(blurRadius: 8, color: Colors.black45),
              ],
            ),
          ),
        ),
        // Settings icon → Profile/Settings page
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
          onPressed: onSettings,
        ),
        // Home icon → Home page
        IconButton(
          icon: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
          onPressed: onHome,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  IMPACT CARD (Glass Blur Effect)
// ─────────────────────────────────────────────
class _ImpactCard extends StatelessWidget {
  final int totalTrees;
  final double total;

  const _ImpactCard({required this.totalTrees, required this.total});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Impact icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              // Impact text
              Expanded(
                child: Text(
                  totalTrees > 0
                      ? 'Your total daily carbon footprint is '
                        '${total.toStringAsFixed(2)} kg CO₂. '
                        'You would need $totalTrees trees to offset '
                        'your annual emissions. Keep reducing! 🌿'
                      : 'Start logging your emissions in the Carbon '
                        'Calculator to see your environmental impact here! 🌿',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.45,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DAILY EMISSION BAR CHART
// ─────────────────────────────────────────────
class _DailyChart extends StatelessWidget {
  final double transportation;
  final double gadgets;
  final double accommodation;

  const _DailyChart({
    required this.transportation,
    required this.gadgets,
    required this.accommodation,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      _BarData('Transport', transportation, const Color(0xFF1A3FC4)),
      _BarData('Gadgets', gadgets, const Color(0xFF4CAF50)),
      _BarData('Accomo', accommodation, const Color(0xFFFFA726)),
    ];

    final maxY = [transportation, gadgets, accommodation]
        .reduce((a, b) => a > b ? a : b);
    // Add 20% headroom, minimum 0.1
    final chartMax = maxY > 0 ? maxY * 1.2 : 0.1;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: chartMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final cat = categories[group.x.toInt()];
                return BarTooltipItem(
                  '${cat.label}\n${cat.value.toStringAsFixed(4)} kg',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
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
                    value.toStringAsFixed(2),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= categories.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      categories[idx].label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMax / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(categories.length, (i) {
            final cat = categories[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: cat.value,
                  color: cat.color,
                  width: 32,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: chartMax,
                    color: Colors.grey[100],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _BarData {
  final String label;
  final double value;
  final Color color;
  const _BarData(this.label, this.value, this.color);
}

// ─────────────────────────────────────────────
//  AI SUGGESTION CARD
// ─────────────────────────────────────────────
class _AISuggestionCard extends StatelessWidget {
  final String? suggestion;
  final bool loading;
  final VoidCallback onRefresh;

  const _AISuggestionCard({
    required this.suggestion,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology,
                  color: Color(0xFF1B5E20), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Suggestions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRefresh,
                child: Icon(Icons.refresh,
                    color: Colors.grey[400], size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1B5E20),
              ),
            )
          else
            Text(
              suggestion ?? 'No suggestions available.',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}