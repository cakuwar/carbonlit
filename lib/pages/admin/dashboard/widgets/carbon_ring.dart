import 'dart:math';
import 'package:flutter/material.dart';

class CarbonRing extends StatefulWidget {
  final double totalEmission;
  final Map<String, double> categoryEmissions;

  const CarbonRing({
    super.key,
    required this.totalEmission,
    required this.categoryEmissions,
  });

  @override
  State<CarbonRing> createState() => _CarbonRingState();
}

class _CarbonRingState extends State<CarbonRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  static const List<Color> _categoryColors = [
    Color(0xFF115925),  // Transportation
    Color(0xFF2196F3),  // Gadgets
    Color(0xFFFF9800),  // Accommodation
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            'Total Carbon Footprint',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizedBox(
                height: 200,
                width: 200,
                child: CustomPaint(
                  painter: _RingPainter(
                    categoryEmissions: widget.categoryEmissions,
                    colors: _categoryColors,
                    progress: _animation.value,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (widget.totalEmission * _animation.value)
                              .toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF115925),
                          ),
                        ),
                        const Text(
                          'kg CO\u2082e',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: widget.categoryEmissions.entries
                .toList()
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final cat = entry.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _categoryColors[i % _categoryColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${cat.key}: ${cat.value.toStringAsFixed(1)}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Map<String, double> categoryEmissions;
  final List<Color> colors;
  final double progress;

  _RingPainter({
    required this.categoryEmissions,
    required this.colors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    const strokeWidth = 24.0;
    final total = categoryEmissions.values.fold(0.0, (a, b) => a + b);

    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -pi / 2;
    final entries = categoryEmissions.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final sweepAngle = (entries[i].value / total) * 2 * pi * progress;
      if (sweepAngle <= 0) continue;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
