import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Leaderboard page visible to all students/staff.
/// Shows real-time ranked list of all users by lowest carbon emissions.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  static const Color _primaryGreen = Color(0xFF115925);

  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  int _userRank = 0;
  String _currentUserId = '';
  String _currentUserName = '';

  // Realtime subscriptions
  RealtimeChannel? _transportChannel;
  RealtimeChannel? _gadgetChannel;
  RealtimeChannel? _accomChannel;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _loadLeaderboard();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _transportChannel?.unsubscribe();
    _gadgetChannel?.unsubscribe();
    _accomChannel?.unsubscribe();
    super.dispose();
  }

  /// Subscribe to real-time changes on emission record tables.
  void _subscribeRealtime() {
    final supabase = Supabase.instance.client;

    _transportChannel = supabase
        .channel('leaderboard_transport')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transport_records',
          callback: (_) => _loadLeaderboard(),
        )
        .subscribe();

    _gadgetChannel = supabase
        .channel('leaderboard_gadgets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gadget_records',
          callback: (_) => _loadLeaderboard(),
        )
        .subscribe();

    _accomChannel = supabase
        .channel('leaderboard_accom')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accommodation_records',
          callback: (_) => _loadLeaderboard(),
        )
        .subscribe();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final supabase = Supabase.instance.client;

      // Bulk load all profiles and emission records
      final allProfiles =
          await supabase.from('profiles').select('id, first_name, last_name');
      final allTransport = await supabase
          .from('transport_records')
          .select('user_id, daily_emission');
      final allGadgets = await supabase
          .from('gadget_records')
          .select('user_id, daily_emission');
      final allAccom = await supabase
          .from('accommodation_records')
          .select('user_id, daily_emission');

      // Aggregate totals per user
      final totals = <String, double>{};
      for (final r in allTransport) {
        final uid = r['user_id'] as String? ?? '';
        totals[uid] = (totals[uid] ?? 0.0) +
            ((r['daily_emission'] as num?)?.toDouble() ?? 0.0);
      }
      for (final r in allGadgets) {
        final uid = r['user_id'] as String? ?? '';
        totals[uid] = (totals[uid] ?? 0.0) +
            ((r['daily_emission'] as num?)?.toDouble() ?? 0.0);
      }
      for (final r in allAccom) {
        final uid = r['user_id'] as String? ?? '';
        totals[uid] = (totals[uid] ?? 0.0) +
            ((r['daily_emission'] as num?)?.toDouble() ?? 0.0);
      }

      final leaderboardData = <Map<String, dynamic>>[];
      for (final p in allProfiles) {
        final pId = p['id'] as String? ?? '';
        final pName =
            '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
        // Only include users who have tracked at least one emission record
        if (totals.containsKey(pId)) {
          leaderboardData.add({
            'id': pId,
            'name': pName.isEmpty ? 'Unknown' : pName,
            'total': totals[pId]!,
          });
        }
      }

      // Sort — lowest emission = rank 1
      leaderboardData
          .sort((a, b) => (a['total'] as double).compareTo(b['total'] as double));

      int rank = 0;
      for (int i = 0; i < leaderboardData.length; i++) {
        if (leaderboardData[i]['id'] == _currentUserId) {
          rank = i + 1;
          _currentUserName = leaderboardData[i]['name'] as String;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _leaderboard = leaderboardData;
          _userRank = rank;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            )
          : RefreshIndicator(
              color: _primaryGreen,
              onRefresh: _loadLeaderboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  // ── Your Rank Card ──
                  _buildYourRankCard(),
                  const SizedBox(height: 16),

                  // ── Top 3 Podium ──
                  if (_leaderboard.length >= 3) ...[
                    _buildPodiumSection(),
                    const SizedBox(height: 16),
                  ],

                  // ── Live indicator ──
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live — updates in real time',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Full ranking list ──
                  _buildFullRankingList(),
                ],
              ),
            ),
    );
  }

  Widget _buildYourRankCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF115925), Color(0xFF1B8C3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _userRank > 0 ? '#$_userRank' : '–',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUserName.isNotEmpty ? _currentUserName : 'You',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userRank > 0
                      ? 'Rank $_userRank of ${_leaderboard.length} tracked users'
                      : 'Start tracking to appear on the leaderboard',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 36),
        ],
      ),
    );
  }

  Widget _buildPodiumSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Top 3',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPodium(_leaderboard[1], 2, 65, const Color(0xFFC0C0C0)),
              _buildPodium(_leaderboard[0], 1, 85, const Color(0xFFFFD700)),
              _buildPodium(_leaderboard[2], 3, 50, const Color(0xFFCD7F32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(
      Map<String, dynamic> user, int rank, double height, Color medalColor) {
    final isCurrentUser = user['id'] == _currentUserId;
    final medals = ['', '1st', '2nd', '3rd'];

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: medalColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              color: medalColor,
              size: rank == 1 ? 28 : 22,
            ),
          ),
          const SizedBox(height: 6),
          CircleAvatar(
            radius: rank == 1 ? 26 : 20,
            backgroundColor: medalColor.withOpacity(0.2),
            child: Text(
              (user['name'] as String).isNotEmpty
                  ? (user['name'] as String)[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: rank == 1 ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCurrentUser
                ? '${(user['name'] as String).split(' ').first} (You)'
                : (user['name'] as String).split(' ').first,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF333333),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${(user['total'] as double).toStringAsFixed(1)} kg',
            style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [medalColor, medalColor.withOpacity(0.4)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text(
                medals[rank],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullRankingList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: _primaryGreen, size: 20),
              const SizedBox(width: 6),
              Text(
                'All Users (${_leaderboard.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...List.generate(_leaderboard.length, (i) {
            final user = _leaderboard[i];
            final isCurrentUser = user['id'] == _currentUserId;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? _primaryGreen.withOpacity(0.08)
                    : (i % 2 == 0
                        ? Colors.grey.withOpacity(0.03)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
                border: isCurrentUser
                    ? Border.all(color: _primaryGreen.withOpacity(0.3))
                    : null,
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 36,
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: i < 3
                            ? _primaryGreen
                            : (isCurrentUser
                                ? _primaryGreen
                                : const Color(0xFF666666)),
                      ),
                    ),
                  ),
                  // Avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isCurrentUser
                        ? _primaryGreen.withOpacity(0.2)
                        : _primaryGreen.withOpacity(0.1),
                    child: Text(
                      (user['name'] as String).isNotEmpty
                          ? (user['name'] as String)[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    child: Text(
                      isCurrentUser
                          ? '${user['name']} (You)'
                          : user['name'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrentUser
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ),
                  // Emission
                  Text(
                    '${(user['total'] as double).toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser
                          ? _primaryGreen
                          : const Color(0xFF888888),
                    ),
                  ),
                  // Medal for top 3
                  if (i < 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: i == 0
                            ? const Color(0xFFFFD700)
                            : (i == 1
                                ? const Color(0xFFC0C0C0)
                                : const Color(0xFFCD7F32)),
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
}
