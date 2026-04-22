import 'package:flutter/material.dart';

class LeaderboardSection extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard;
  final int userRank;
  final String currentUserId;

  const LeaderboardSection({
    super.key,
    required this.leaderboard,
    required this.userRank,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final topUsers = leaderboard.take(10).toList();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 6),
              const Text(
                'Leaderboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF115925).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Your Rank: #$userRank',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115925),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top 3 podium
          if (topUsers.length >= 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPodium(topUsers[1], 2, 65, const Color(0xFFC0C0C0)),
                  _buildPodium(topUsers[0], 1, 85, const Color(0xFFFFD700)),
                  _buildPodium(topUsers[2], 3, 50, const Color(0xFFCD7F32)),
                ],
              ),
            ),

          if (topUsers.length >= 3) ...[
            const SizedBox(height: 16),
            const Divider(),
          ],

          // Remaining users list
          ...topUsers.skip(3).toList().asMap().entries.map((entry) {
            final i = entry.key + 3;
            final user = entry.value;
            final isCurrentUser = user['id'] == currentUserId;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? const Color(0xFF115925).withOpacity(0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isCurrentUser
                    ? Border.all(
                        color: const Color(0xFF115925).withOpacity(0.3))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isCurrentUser
                            ? const Color(0xFF115925)
                            : const Color(0xFF666666),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        const Color(0xFF115925).withOpacity(0.1),
                    child: Text(
                      (user['name'] as String).isNotEmpty
                          ? (user['name'] as String)[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF115925),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                  Text(
                    '${(user['total'] as double).toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser
                          ? const Color(0xFF115925)
                          : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Show "you" if not in top 10
          if (userRank > 10)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF115925).withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF115925).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('...', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  Text(
                    '#$userRank',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF115925),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        const Color(0xFF115925).withOpacity(0.1),
                    child: const Icon(Icons.person,
                        size: 16, color: Color(0xFF115925)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'You',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPodium(
      Map<String, dynamic> user, int rank, double height, Color medalColor) {
    final isCurrentUser = user['id'] == currentUserId;
    final medals = ['', '1st', '2nd', '3rd'];

    return Expanded(
      child: Column(
        children: [
          // Medal icon
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
          // Avatar
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
                color: const Color(0xFF115925),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCurrentUser
                ? 'You'
                : (user['name'] as String).split(' ').first,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  isCurrentUser ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF333333),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${(user['total'] as double).toStringAsFixed(1)} kg',
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 4),
          // Podium bar
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
}
