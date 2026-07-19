import 'package:flutter/material.dart';

import '../admin_colors.dart';

/// A minimal line chart drawn with CustomPainter — no chart package
/// dependency needed. Pass month labels + values in the same order.
class MiniLineChart extends StatefulWidget {
  final List<String> labels;
  final List<double> values;

  const MiniLineChart({super.key, required this.labels, required this.values});

  @override
  State<MiniLineChart> createState() => _MiniLineChartState();
}

class _MiniLineChartState extends State<MiniLineChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No sales data yet', style: TextStyle(color: kAdminCardGrey))),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanUpdate: (details) => _updateHover(details.localPosition.dx, width),
          onPanEnd: (_) => setState(() => _hoverIndex = null),
          onTapDown: (details) => _updateHover(details.localPosition.dx, width),
          child: SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                values: widget.values,
                labels: widget.labels,
                hoverIndex: _hoverIndex,
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateHover(double dx, double width) {
    final count = widget.values.length;
    if (count <= 1) return;
    final step = width / (count - 1);
    final index = (dx / step).round().clamp(0, count - 1);
    setState(() => _hoverIndex = index);
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final int? hoverIndex;

  _LineChartPainter({required this.values, required this.labels, required this.hoverIndex});

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 24.0; // room for month labels
    final chartHeight = size.height - bottomPad;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1 : maxVal * 1.2;

    final points = <Offset>[];
    final stepX = values.length > 1 ? size.width / (values.length - 1) : 0.0;
    for (int i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y = chartHeight - (values[i] / safeMax * chartHeight);
      points.add(Offset(x, y));
    }

    // Gradient fill under the line.
    final fillPath = Path()..moveTo(points.first.dx, chartHeight);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kAdminBlue.withValues(alpha: 0.25), kAdminBlue.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // The line itself.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = kAdminBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Dots + month labels.
    TextPainter textPainterBuilder(String text, Color color) => TextPainter(
          text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();

    for (int i = 0; i < points.length; i++) {
      final isHover = i == hoverIndex;
      canvas.drawCircle(points[i], isHover ? 5 : 3, Paint()..color = kAdminBlue);
      if (isHover) {
        canvas.drawCircle(points[i], 8, Paint()..color = kAdminBlue.withValues(alpha: 0.2));
      }

      final label = textPainterBuilder(labels[i], kAdminCardGrey);
      label.paint(canvas, Offset(points[i].dx - label.width / 2, chartHeight + 6));
    }

    // Hover tooltip.
    if (hoverIndex != null) {
      final p = points[hoverIndex!];
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, chartHeight), Paint()..color = kAdminBorder);

      final valueText = textPainterBuilder('₱${values[hoverIndex!].toStringAsFixed(0)}', kAdminDarkBlue);
      final boxWidth = valueText.width + 16;
      final boxLeft = (p.dx - boxWidth / 2).clamp(0, size.width - boxWidth);
      final boxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxLeft.toDouble(), p.dy - 34, boxWidth, 24),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        boxRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        boxRect,
        Paint()
          ..color = kAdminBorder
          ..style = PaintingStyle.stroke,
      );
      valueText.paint(canvas, Offset(boxLeft + 8, p.dy - 28));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex || oldDelegate.values != values;
}
