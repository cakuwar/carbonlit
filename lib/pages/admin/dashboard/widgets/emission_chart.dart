import 'package:flutter/material.dart';

class EmissionChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;

  const EmissionChart({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final maxEmission = weeklyData.fold<double>(
      0.1,
      (prev, e) =>
          (e['emission'] as double) > prev ? (e['emission'] as double) : prev,
    );

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
          const Text(
            'Weekly Emissions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.map((data) {
                final emission = data['emission'] as double;
                final height = (emission / maxEmission) * 120;
                final isToday = data == weeklyData.last;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          emission > 0 ? emission.toStringAsFixed(1) : '',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? const Color(0xFF115925)
                                : const Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          height: height.clamp(4.0, 120.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isToday
                                  ? [
                                      const Color(0xFF115925),
                                      const Color(0xFF1E8449)
                                    ]
                                  : [
                                      const Color(0xFFB8D8BE),
                                      const Color(0xFFA5D6A7)
                                    ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['day'] ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? const Color(0xFF115925)
                                : const Color(0xFF999999),
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
