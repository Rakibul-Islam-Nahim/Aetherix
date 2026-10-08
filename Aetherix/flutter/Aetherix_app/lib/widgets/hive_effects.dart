import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Subtle hacker-vibe backdrop: a tiled 24x24 grid drawn faintly plus a
/// slow horizontal scanline that moves top → bottom. Mounted once at
/// the root. Drops frames gracefully — pure CustomPaint, no per-frame
/// allocations.
class HackerBackdrop extends StatefulWidget {
  const HackerBackdrop({super.key, this.child});
  final Widget? child;

  @override
  State<HackerBackdrop> createState() => _HackerBackdropState();
}

class _HackerBackdropState extends State<HackerBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (context, _) => CustomPaint(
                painter: _GridScanlinePainter(_ctl.value),
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _GridScanlinePainter extends CustomPainter {
  _GridScanlinePainter(this.t);
  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.lime.withValues(alpha: 0.045)
      ..strokeWidth = 0.6;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // Moving scanline
    final scan = (t * size.height) % size.height;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.lime.withValues(alpha: 0.0),
          AppColors.lime.withValues(alpha: 0.05),
          AppColors.lime.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTWH(0, scan - 40, size.width, 80),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, scan - 40, size.width, 80),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GridScanlinePainter old) => old.t != t;
}

/// Pulsing status indicator — slower, more atmospheric than a heartbeat.
class PulseGlow extends StatefulWidget {
  const PulseGlow(
    this.label, {
    super.key,
    this.color = AppColors.lime,
    this.size = 6,
  });

  final String label;
  final Color color;
  final double size;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) {
            final v = _ctl.value;
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4 + 0.4 * v),
                    blurRadius: 4 + 8 * v,
                    spreadRadius: 1 + 2 * v,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: AppSpacing.xs),
        MonoText(widget.label, color: widget.color, size: 10),
      ],
    );
  }
}

/// Marquee banner — single line of monospace text scrolling left.
/// Use sparingly, e.g. a system status line.
class TerminalMarquee extends StatefulWidget {
  const TerminalMarquee({
    super.key,
    required this.text,
    this.color = AppColors.lime,
    this.speedPxPerSec = 60,
  });
  final String text;
  final Color color;
  final double speedPxPerSec;

  @override
  State<TerminalMarquee> createState() => _TerminalMarqueeState();
}

class _TerminalMarqueeState extends State<TerminalMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final double _travelPx;

  @override
  void initState() {
    super.initState();
    final secs = widget.text.length / 6.0;
    _travelPx = widget.speedPxPerSec * secs;
    _ctl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (secs * 1000).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) {
            final dx = -_ctl.value * _travelPx;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Transform.translate(
                  offset: Offset(dx, 0),
                  child: Text(
                    '${widget.text}    //    ${widget.text}    //    ',
                    style: TextStyle(
                      color: widget.color.withValues(alpha: 0.7),
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Animated integer counter that smoothly tweens between values.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        v.toInt().toString(),
        style: style,
      ),
    );
  }
}

/// Glitch text: the same text drawn three times with tiny chromatic
/// offset + alpha flicker, producing a "bad reception" effect. Use for
/// headers only — it's expensive.
class GlitchText extends StatefulWidget {
  const GlitchText(
    this.text, {
    super.key,
    this.style,
    this.intensity = 1.0,
  });

  final String text;
  final TextStyle? style;
  final double intensity;

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final _rnd = math.Random(42);

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? Theme.of(context).textTheme.headlineMedium;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        // Only glitch a fraction of frames, then settle.
        final glitchOn = _ctl.value < 0.06 || (_ctl.value > 0.5 && _ctl.value < 0.55);
        final dx = glitchOn ? (_rnd.nextDouble() - 0.5) * 2.5 * widget.intensity : 0.0;
        final dy = glitchOn ? (_rnd.nextDouble() - 0.5) * 1.0 * widget.intensity : 0.0;
        return Stack(
          children: [
            // Cyan offset
            if (glitchOn)
              Text(
                widget.text,
                style: base?.copyWith(
                  color: Color(0xFF00FFFF).withValues(alpha: 0.6),
                ),
              ),
            // Magenta offset
            Transform.translate(
              offset: Offset(dx, dy),
              child: Text(
                widget.text,
                style: glitchOn
                    ? base?.copyWith(
                        color: Color(0xFFFF00FF).withValues(alpha: 0.6),
                      )
                    : base,
              ),
            ),
            // Top layer (clean)
            if (glitchOn)
              Text(
                widget.text,
                style: base,
              ),
          ],
        );
      },
    );
  }
}

/// Animated border ring — draws lime stroke clockwise around a child.
class AnimatedBorder extends StatefulWidget {
  const AnimatedBorder({
    super.key,
    required this.child,
    this.color = AppColors.lime,
    this.strokeWidth = 1.2,
    this.radius = AppRadii.small,
    this.duration = const Duration(seconds: 6),
  });
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double radius;
  final Duration duration;

  @override
  State<AnimatedBorder> createState() => _AnimatedBorderState();
}

class _AnimatedBorderState extends State<AnimatedBorder>
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
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => CustomPaint(
        foregroundPainter: _StrokeSweepPainter(
          t: _ctl.value,
          color: widget.color,
          stroke: widget.strokeWidth,
          radius: widget.radius,
        ),
        child: widget.child,
      ),
    );
  }
}

class _StrokeSweepPainter extends CustomPainter {
  _StrokeSweepPainter({
    required this.t,
    required this.color,
    required this.stroke,
    required this.radius,
  });
  final double t;
  final Color color;
  final double stroke;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(stroke / 2), r);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, paint);

    final sweep = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final start = -math.pi / 2 + 2 * math.pi * t;
    canvas.drawArc(
      Rect.fromLTWH(rrect.left, rrect.top, rrect.width, rrect.height),
      start,
      math.pi * 0.35,
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(covariant _StrokeSweepPainter old) =>
      old.t != t || old.color != color;
}

/// Shimmer skeleton: a moving lime gradient across a child.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.color = AppColors.lime,
    this.duration = const Duration(milliseconds: 1400),
  });
  final Widget child;
  final Color color;
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
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
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-1 + 2 * _ctl.value, 0),
          end: Alignment(1 + 2 * _ctl.value, 0),
          colors: [
            Colors.transparent,
            widget.color.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(rect),
        child: widget.child,
      ),
    );
  }
}