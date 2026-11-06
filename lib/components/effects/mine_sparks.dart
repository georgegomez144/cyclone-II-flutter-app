import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

const double kMineSpinSpeed = 4.5;

class MineSparks extends PositionComponent {
  MineSparks({required this.radius, math.Random? random})
    : _random = random ?? math.Random();

  static const int maxSparkCount = 18;
  static const double _emissionRate = 45;
  static const double _goldenAngle = 2.399963229728653;

  final double radius;
  final math.Random _random;
  final List<_MineSpark> _sparks = [];
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final Paint _corePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.2;

  double _emissionAccumulator = 0;
  int _emittedSparkCount = 0;

  int get activeSparkCount => _sparks.length;

  List<Vector2> get sparkPositions => List<Vector2>.unmodifiable(
    _sparks.map((spark) => spark.position.clone()),
  );

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;

    for (final spark in _sparks) {
      spark.position.add(spark.velocity * dt);
      spark.life -= dt;
    }
    _sparks.removeWhere((spark) => spark.life <= 0);

    _emissionAccumulator += dt;
    final emissionCount = (_emissionAccumulator * _emissionRate).floor();
    _emissionAccumulator -= emissionCount / _emissionRate;
    final sparksToEmit = math.min(
      emissionCount,
      maxSparkCount - _sparks.length,
    );
    for (var i = 0; i < sparksToEmit; i++) {
      _emitSpark();
    }
  }

  void _emitSpark() {
    final angle = _emittedSparkCount * _goldenAngle;
    _emittedSparkCount++;
    final radial = Vector2(math.cos(angle), math.sin(angle));
    final lifetime = 0.32 + _random.nextDouble() * 0.12;
    final travel = radius * (0.6 + _random.nextDouble() * 0.3);

    _sparks.add(
      _MineSpark(
        position: radial * radius,
        velocity: radial * (travel / lifetime),
        origin: radial * radius,
        life: lifetime,
        maxLife: lifetime,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    for (final spark in _sparks) {
      final progress = (spark.life / spark.maxLife).clamp(0.0, 1.0);
      _glowPaint.color = Colors.orange.withValues(alpha: 0.25 * progress);
      _corePaint.color = Color.lerp(
        Colors.yellowAccent,
        Colors.orangeAccent,
        1 - progress,
      )!.withValues(alpha: 0.55 * progress);

      final end = spark.position.toOffset();
      final start = spark.origin.toOffset();
      canvas.drawLine(start, end, _glowPaint);
      canvas.drawLine(start, end, _corePaint);
      canvas.drawCircle(end, 1.6, _glowPaint..style = PaintingStyle.fill);
      canvas.drawCircle(end, 0.9, _corePaint..style = PaintingStyle.fill);
      _glowPaint.style = PaintingStyle.stroke;
      _corePaint.style = PaintingStyle.stroke;
    }
  }
}

class _MineSpark {
  _MineSpark({
    required this.position,
    required this.velocity,
    required this.origin,
    required this.life,
    required this.maxLife,
  });

  final Vector2 position;
  final Vector2 velocity;
  final Vector2 origin;
  double life;
  final double maxLife;
}
