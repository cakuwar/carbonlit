import 'package:flutter/material.dart';

class GoalsSection extends StatelessWidget {
  final double totalEmission;
  final double goalTarget;

  const GoalsSection({
    super.key,
    required this.totalEmission,
    required this.goalTarget,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goalTarget > 0
        ? (totalEmission / goalTarget).clamp(0.0, 1.0)
        : 0.0;
    final isOnTrack = totalEmission <= goalTarget;

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
              const Icon(Icons.flag, color: Color(0xFF115925), size: 20),
              const SizedBox(width: 6),
              const Text(
                'Weekly Goal',
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
                  color: isOnTrack
                      ? const Color(0xFF115925).withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnTrack ? Icons.check_circle : Icons.warning,
                      size: 14,
                      color: isOnTrack ? const Color(0xFF115925) : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnTrack ? 'On Track' : 'Over Target',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isOnTrack ? const Color(0xFF115925) : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOnTrack ? const Color(0xFF115925) : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${totalEmission.toStringAsFixed(1)} kg CO\u2082e',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
              Text(
                'Goal: ${goalTarget.toStringAsFixed(0)} kg CO\u2082e',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
