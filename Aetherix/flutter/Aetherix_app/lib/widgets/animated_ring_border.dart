import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A circular border around [child] where a lime "snake" continuously
/// orbits the rim.
///
/// Implementation notes
/// --------------------
/// - The base ring is a faint full circle (low-alpha lime) so the
///   shape reads even when the snake sweeps over a busy icon edge.
/// - The snake is a single arc that rotates 360° on a repeating
///   [AnimationController]. We paint it as a stroked path so the
///   rounding of the arc ends matches the rest of the lime motif.
/// - [snakeLength] is the arc length as a fraction of a full
///   revolution. 0.25 = a quarter-circle; the user picked "a serpent
///   circling" so 0.28 reads as a confident sweep without being a
///   full ring (which would just look like a solid border).
/// - The widget sizes itself to the child — pass it a square child
///   (e.g. 32x32) and it draws a 32x32 ring around it.
class AnimatedRingBorder extends StatefulWidget {
  const AnimatedRingBorder({
    super.key,
    required this.child,
    this.size = 36,
    this.baseRingAlpha = 0.18,
    this.snakeColor,
    this.snakeLength = 0.28,
    this.strokeWidth = 1.4,
    this.duration = const Duration(seconds: 3),
  });

  final Widget child;
  final double size;
  final double baseRingAlpha;
  final Color? snakeColor;
  final double snakeLength;
  final double strokeWidth;
  final Duration duration;

  @override
  State<AnimatedRingBorder> createState() => _AnimatedRingBorderState();
}

class _AnimatedRingBorderState extends State<AnimatedRingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.snakeColor ?? AppColors.lime;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The base ring — always visible so the icon is "framed"
          // even when the snake is on the far side.
          CustomPaint(
            size: Size.square(widget.size),
            painter: _BaseRingPainter(
              color: color.withValues(alpha: widget.baseRingAlpha),
              strokeWidth: widget.strokeWidth,
            ),
          ),
          // The animated snake — drawn over the base.
          AnimatedBuilder(
            animation: _ctl,
            builder: (context, _) {
              return CustomPaint(
                size: Size.square(widget.size),
                painter: _SnakePainter(
                  progress: _ctl.value,
                  color: color,
                  arcFraction: widget.snakeLength,
                  strokeWidth: widget.strokeWidth,
                ),
              );
            },
          ),
          // The icon itself, inset so it never touches the ring.
          Padding(
            padding: EdgeInsets.all(widget.strokeWidth + 2),
            child: ClipOval(
              // The icon already has a black background, so the inner
              // mask is a no-op for the asset but keeps the
              // widget resilient if a transparent asset is ever
              // swapped in.
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _BaseRingPainter extends CustomPainter {
  _BaseRingPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BaseRingPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _SnakePainter extends CustomPainter {
  _SnakePainter({
    required this.progress,
    required this.color,
    required this.arcFraction,
    required this.strokeWidth,
  });

  /// 0.0 .. 1.0, the rotation of the snake's leading edge.
  final double progress;
  final Color color;
  final double arcFraction;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Start at 12 o'clock, sweep clockwise. A small negative start
    // (-pi/2) rotates the arc so its leading edge is at the top at
    // progress = 0.
    final start = -math.pi / 2 + progress * 2 * math.pi;
    final sweep = arcFraction * 2 * math.pi;

    // Glow underlay for the "active" part of the snake — gives the
    // border the same neon feel as the rest of the app.
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawArc(rect, start, sweep, false, glow);

    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_SnakePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.arcFraction != arcFraction ||
      old.strokeWidth != strokeWidth;
}
