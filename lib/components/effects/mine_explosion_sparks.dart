import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MineExplosionSparks extends PositionComponent {
  MineExplosionSparks({math.Random? random})
    : _random = random ?? math.Random() {
    _emitBurst();
  }

  static const int sparkCount = 24;

  final math.Random _random;
  final List<_MineExplosionSpark> _sparks = [];
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 4
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final Paint _corePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.5;

  int get activeSparkCount => _sparks.length;

  bool get isFinished => _sparks.isEmpty;

  List<Vector2> get sparkPositions => List<Vector2>.unmodifiable(
    _sparks.map((spark) => spark.position.clone()),
  );

  void _emitBurst() {
    for (var i = 0; i < sparkCount; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final direction = Vector2(math.cos(angle), math.sin(angle));
      final speed = 90 + _random.nextDouble() * 90;
      final lifetime = 0.25 + _random.nextDouble() * 0.25;

      _sparks.add(
        _MineExplosionSpark(
          position: Vector2.zero(),
          velocity: direction * speed,
          direction: direction,
          life: lifetime,
          maxLife: lifetime,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;

    for (final spark in _sparks) {
      spark.position.add(spark.velocity * dt);
      spark.life -= dt;
    }
    _sparks.removeWhere((spark) => spark.life <= 0);
    if (isFinished && isMounted) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    for (final spark in _sparks) {
      final progress = (spark.life / spark.maxLife).clamp(0.0, 1.0);
      _glowPaint
        ..strokeWidth = 4 * progress
        ..color = Colors.orange.withValues(alpha: 0.7 * progress);
      _corePaint
        ..strokeWidth = 1.5 * progress
        ..color = Color.lerp(
          Colors.orange,
          Colors.white,
          progress,
        )!.withValues(alpha: progress);

      final end = spark.position.toOffset();
      final start = (spark.position - spark.direction * 7).toOffset();
      canvas.drawLine(start, end, _glowPaint);
      canvas.drawLine(start, end, _corePaint);
    }
  }
}

class _MineExplosionSpark {
  _MineExplosionSpark({
    required this.position,
    required this.velocity,
    required this.direction,
    required this.life,
    required this.maxLife,
  });

  final Vector2 position;
  final Vector2 velocity;
  final Vector2 direction;
  double life;
  final double maxLife;
}
