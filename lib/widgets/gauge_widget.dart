import 'package:flutter/material.dart';
import 'dart:math' as math;

class GaugeWidget extends StatelessWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final String label;
  final String unit;
  final Color color;

  const GaugeWidget({
    super.key,
    required this.value,
    this.minValue = 0,
    this.maxValue = 100,
    this.label = '数值',
    this.unit = '',
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CustomPaint(
            painter: _GaugePainter(
              percentage: percentage,
              color: color,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${minValue.toStringAsFixed(0)} - ${maxValue.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;

  _GaugePainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * percentage,
      false,
      valuePaint,
    );

    final tickPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + (sweepAngle * i / 10);
      final innerRadius = radius - 20;
      final outerRadius = radius - 8;

      final innerPoint = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      final outerPoint = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color;
  }
}
