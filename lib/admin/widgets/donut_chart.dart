import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../admin_colors.dart';

class DonutSlice {
  final String label;
  final double value;
  final Color color;
  const DonutSlice({required this.label, required this.value, required this.color});
}

/// Donut chart + legend, drawn with CustomPainter — no chart package
/// dependency required.
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;

  const DonutChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('No product data yet', style: TextStyle(color: kAdminCardGrey))),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 130,
          width: 130,
          child: CustomPaint(painter: _DonutPainter(slices: slices, total: total)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: slices.map((s) {
              final pct = (s.value / total * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(height: 8, width: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: kAdminDarkBlue)),
                    ),
                    Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double total;

  _DonutPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const strokeWidth = 20.0;
    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweep = (slice.value / total) * 2 * math.pi;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.slices != slices;
}
