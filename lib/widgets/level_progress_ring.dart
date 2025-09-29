import 'dart:math' as math;
import 'package:flutter/material.dart';

class LevelProgressRing extends StatelessWidget {
  final int totalSegments;
  final int completedSegments;
  final double outerRadius;
  final double strokeWidth;
  final double gapDegrees;
  final bool showTrack;
  final double trackOpacity;
  final Color completedColor;
  final Color remainingColor;

  const LevelProgressRing({
    super.key,
    required this.totalSegments,
    required this.completedSegments,
    this.outerRadius = 44,
    this.strokeWidth = 8,
    this.gapDegrees = 8,
    this.showTrack = true,
    this.trackOpacity = 0.28,
    this.completedColor = const Color(0xFF58CC02),
    this.remainingColor = const Color(0xFF9CA3AF),
  });

  @override
  Widget build(BuildContext context) {
    if (totalSegments <= 0) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      size: Size(outerRadius * 2, outerRadius * 2),
      painter: _SegmentsPainter(
        total: totalSegments,
        completed: completedSegments.clamp(0, totalSegments),
        strokeWidth: strokeWidth,
        gapRadians: math.pi / 180 * gapDegrees,
        showTrack: showTrack,
        trackOpacity: trackOpacity,
        completedColor: completedColor,
        remainingColor: remainingColor,
      ),
    );
  }
}

class _SegmentsPainter extends CustomPainter {
  final int total;
  final int completed;
  final double strokeWidth;
  final double gapRadians;
  final bool showTrack;
  final double trackOpacity;
  final Color completedColor;
  final Color remainingColor;

  _SegmentsPainter({
    required this.total,
    required this.completed,
    required this.strokeWidth,
    required this.gapRadians,
    required this.showTrack,
    required this.trackOpacity,
    required this.completedColor,
    required this.remainingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - strokeWidth / 2;

    // Soft glow for completed segments to improve visibility on dark/blue bg
    final glowPaint = Paint()
      ..color = completedColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paintCompleted = Paint()
      ..color = completedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintRemaining = Paint()
      ..color = remainingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: trackOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final segmentAngle = 2 * math.pi / total;
    final sweep = segmentAngle - gapRadians;

    // Optional track (light segments under everything for contrast)
    if (showTrack) {
      for (int i = 0; i < total; i++) {
        final startAngle = -math.pi / 2 + i * segmentAngle + gapRadians / 2;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweep,
          false,
          trackPaint,
        );
      }
    }

    // Draw remaining segments (subtle) and completed (with glow + solid)
    for (int i = 0; i < total; i++) {
      final startAngle = -math.pi / 2 + i * segmentAngle + gapRadians / 2;
      final isCompleted = i < completed;
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      if (isCompleted) {
        // Glow first, then the solid stroke on top
        canvas.drawArc(arcRect, startAngle, sweep, false, glowPaint);
        canvas.drawArc(arcRect, startAngle, sweep, false, paintCompleted);
      } else {
        // For remaining, keep it subtle so the track provides contrast
        canvas.drawArc(arcRect, startAngle, sweep, false, paintRemaining);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentsPainter oldDelegate) {
    return total != oldDelegate.total ||
        completed != oldDelegate.completed ||
        strokeWidth != oldDelegate.strokeWidth ||
        gapRadians != oldDelegate.gapRadians ||
        showTrack != oldDelegate.showTrack ||
        trackOpacity != oldDelegate.trackOpacity ||
        completedColor != oldDelegate.completedColor ||
        remainingColor != oldDelegate.remainingColor;
  }
}