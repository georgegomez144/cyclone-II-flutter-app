import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Electrifying one-shot shield effect: animated arcs and sparks around a ring.
///
/// Lightweight and self-contained: draws procedurally without textures.
/// Intended to be added as a child of the Player when the one-shot shield is active.
class ElectricShield extends PositionComponent {
  ElectricShield({
    required this.radius,
    this.strokeWidth = 1.4,
    this.arcCount = 3,
    this.color = const Color(0x668FE7FF),
  }) : super(anchor: Anchor.center, size: Vector2.all(1));

  final double radius;
  final double strokeWidth;
  final int arcCount;
  final Color color;

  double _t = 0; // time accumulator for animation
  final math.Random _rng = math.Random();

  @override
  void update(double dt) {
    super.update(dt);
    // Advance time; limit to avoid floating overflow
    _t += dt;
    if (_t > 1000) _t = 0;
  }

  @override
  void render(Canvas canvas) {
    // Slight pulsing outer glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2
      ..color = color.withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 16);

    // Base faint ring
    final baseRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.15);

    canvas.drawCircle(Offset.zero, radius, glowPaint);
    canvas.drawCircle(Offset.zero, radius, baseRing);

    // Animated electric arcs
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.95);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 1.6
      ..color = color.withOpacity(0.9);

    // Draw multiple short jittery arc segments around the circumference
    // Each arc length ~ 30-60 degrees; positions vary over time
    final double basePhase = _t * 2.2; // angular motion speed
    for (int i = 0; i < arcCount; i++) {
      // Pseudo-random but time-shifted angle for each arc
      final double seed = i * 37.123 + basePhase;
      final double startA = _hashToUnit(seed) * math.pi * 2;
      final double span = lerpDouble(
        0.5,
        1.0,
        _hashToUnit(seed + 19.7),
      )!; // 0.5..1.0 rad
      _drawJaggedArc(canvas, startA, span, arcPaint, accentPaint);
    }

    // Occasional sparks jumping off the ring
    // Draw 1-2 per frame with small probability
    if (_rng.nextDouble() < 0.25) {
      final double a = _rng.nextDouble() * math.pi * 2;
      final double len = 6.0 + _rng.nextDouble() * 10.0;
      final double jitter = (_rng.nextDouble() - 0.5) * 0.4;
      final Offset p0 = Offset(math.cos(a) * radius, math.sin(a) * radius);
      final Offset p1 = Offset(
        math.cos(a + jitter) * (radius + len),
        math.sin(a + jitter) * (radius + len),
      );
      final Paint spark = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.2
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(0.95);
      canvas.drawLine(p0, p1, spark);
    }
  }

  void _drawJaggedArc(
    Canvas canvas,
    double startAngle,
    double span,
    Paint arcPaint,
    Paint accentPaint,
  ) {
    // Split arc into small segments with radial jitter to simulate electricity
    final int steps = (span / 0.12).clamp(5, 20).toInt();
    final Path path = Path();
    for (int s = 0; s <= steps; s++) {
      final double t = s / steps;
      final double a = startAngle + span * t;
      final double jitter =
          (math.sin((a + _t * 6.0) * 7.0) + math.sin((a * 3.0) - _t * 5.0)) *
          0.8;
      final double rJ = radius + jitter; // small radial jitter
      final Offset p = Offset(math.cos(a) * rJ, math.sin(a) * rJ);
      if (s == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, accentPaint);
    canvas.drawPath(path, arcPaint);
  }

  double _hashToUnit(double x) {
    // Simple hash to [0,1)
    final double s = math.sin(x * 12.9898) * 43758.5453;
    return s - s.floorToDouble();
  }
}
