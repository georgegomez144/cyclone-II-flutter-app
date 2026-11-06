import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CastleExplosion extends PositionComponent {
  CastleExplosion({
    this.maxRadius = 100,
    this.duration = 1,
    math.Random? random,
  }) : _random = random ?? math.Random(),
       super(anchor: Anchor.center, size: Vector2.all(1)) {
    assert(maxRadius >= 0);
    assert(duration > 0);
  }

  static const int sparkCount = 120;
  static const double _flashFraction = 0.3;
  static const List<double> _ringStartFractions = [0, 0.16, 0.32, 0.48, 0.6];
  static const List<double> _ringRadiusFractions = [0.4, 0.65, 0.9, 1.15, 1.4];
  static const Color _whiteHot = Color(0xFFFFF6E5);
  static const Color _paleGold = Color(0xFFFFD98C);
  static const List<Color> _ringColors = [
    _whiteHot,
    Color(0xFFFFE4B0),
    Color(0xFFFFC27A),
    Color(0xFFFF9E5E),
    Color(0xFFFF8A65),
  ];

  final double maxRadius;
  final double duration;
  final math.Random _random;
  final List<_CastleSpark> _sparks = [];
  final List<Paint> _ringPaints = List.generate(
    _ringColors.length,
    (_) => Paint()
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  final List<Paint> _ringGlowPaints = List.generate(
    _ringColors.length,
    (_) => Paint()
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
  );
  final Paint _flashPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
  final Paint _flashCorePaint = Paint()..style = PaintingStyle.fill;
  final Paint _sparkGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  final Paint _sparkCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _sparkHeadPaint = Paint()..style = PaintingStyle.fill;

  double _elapsed = 0;
  bool _started = false;

  int get activeSparkCount => _sparks.length;

  int get activeRingCount {
    if (!_started || _elapsed >= duration) return 0;
    return _ringStartFractions
        .where((fraction) => _elapsed >= duration * fraction)
        .length;
  }

  bool get isFinished => _started && _elapsed >= duration && _sparks.isEmpty;

  List<Vector2> get sparkPositions => List<Vector2>.unmodifiable(
    _sparks.map((spark) => spark.position.clone()),
  );

  @override
  void update(double dt) {
    super.update(dt);
    if (!_started) {
      _started = true;
      _emitSparks();
    }
    if (dt <= 0) return;

    _elapsed = math.min(_elapsed + dt, duration);
    for (final spark in _sparks) {
      spark.position.add(spark.velocity * dt);
      spark.velocity.scale(math.exp(-spark.drag * dt));
      spark.life -= dt;
    }
    _sparks.removeWhere((spark) => spark.life <= 0);

    if (isFinished) removeFromParent();
  }

  void _emitSparks() {
    for (var i = 0; i < sparkCount; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final radial = Vector2(math.cos(angle), math.sin(angle));
      final tangent = Vector2(-radial.y, radial.x);
      final direction =
          (radial * (0.7 + _random.nextDouble() * 0.3) +
                  tangent * ((_random.nextDouble() - 0.5) * 0.6))
              .normalized();
      final speed = 150 + _random.nextDouble() * 260;
      final lifetime = duration * (0.62 + _random.nextDouble() * 0.32);

      _sparks.add(
        _CastleSpark(
          position: radial * (_random.nextDouble() * maxRadius * 0.15),
          velocity: direction * speed,
          direction: direction,
          drag: 1.6 + _random.nextDouble() * 1.4,
          life: lifetime,
          maxLife: lifetime,
          thickness: 0.8 + _random.nextDouble() * 0.6,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_started) return;

    _renderFlash(canvas);
    _renderRings(canvas);
    _renderSparks(canvas);
  }

  void _renderFlash(Canvas canvas) {
    final flashDuration = duration * _flashFraction;
    if (_elapsed >= flashDuration) return;

    final progress = (_elapsed / flashDuration).clamp(0.0, 1.0);
    final fade = 1 - Curves.easeIn.transform(progress);
    final radius =
        maxRadius * (0.35 + 0.45 * Curves.easeOut.transform(progress));
    _flashPaint.color = Colors.orangeAccent.withValues(alpha: 0.75 * fade);
    _flashCorePaint.color = _whiteHot.withValues(alpha: 0.9 * fade);
    canvas.drawCircle(Offset.zero, radius, _flashPaint);
    canvas.drawCircle(Offset.zero, radius * 0.45, _flashCorePaint);
  }

  void _renderRings(Canvas canvas) {
    for (var i = 0; i < _ringStartFractions.length; i++) {
      final startTime = duration * _ringStartFractions[i];
      if (_elapsed < startTime || _elapsed >= duration) continue;

      final progress = ((_elapsed - startTime) / (duration - startTime)).clamp(
        0.0,
        1.0,
      );
      final radius =
          maxRadius *
          _ringRadiusFractions[i] *
          Curves.easeOutCubic.transform(progress);
      final fade = 1 - Curves.easeIn.transform(progress);
      final glowPaint = _ringGlowPaints[i]
        ..strokeWidth = 14 + 22 * fade
        ..color = _ringColors[i].withValues(alpha: 0.35 * fade);
      final paint = _ringPaints[i]
        ..strokeWidth = 2 + 6 * fade
        ..color = _ringColors[i].withValues(alpha: 0.7 * fade);
      canvas.drawCircle(Offset.zero, radius, glowPaint);
      canvas.drawCircle(Offset.zero, radius, paint);
    }
  }

  void _renderSparks(Canvas canvas) {
    for (final spark in _sparks) {
      final progress = (spark.life / spark.maxLife).clamp(0.0, 1.0);
      final trail = (spark.velocity.length * 0.07).clamp(4.0, 22.0);
      _sparkGlowPaint
        ..strokeWidth = 7 * progress * spark.thickness
        ..color = Color.lerp(
          Colors.redAccent,
          Colors.orangeAccent,
          progress,
        )!.withValues(alpha: 0.85 * progress);
      _sparkCorePaint
        ..strokeWidth = 2.5 * progress * spark.thickness
        ..color = Color.lerp(
          _paleGold,
          _whiteHot,
          progress,
        )!.withValues(alpha: progress);
      _sparkHeadPaint.color = _whiteHot.withValues(alpha: progress);

      final end = spark.position.toOffset();
      final start = (spark.position - spark.direction * trail).toOffset();
      canvas.drawLine(start, end, _sparkGlowPaint);
      canvas.drawLine(start, end, _sparkCorePaint);
      canvas.drawCircle(end, 1.8 * progress * spark.thickness, _sparkHeadPaint);
    }
  }
}

class _CastleSpark {
  _CastleSpark({
    required this.position,
    required this.velocity,
    required this.direction,
    required this.drag,
    required this.life,
    required this.maxLife,
    required this.thickness,
  });

  final Vector2 position;
  final Vector2 velocity;
  final Vector2 direction;
  final double drag;
  double life;
  final double maxLife;
  final double thickness;
}
