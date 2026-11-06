import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ShieldSegmentSparks extends PositionComponent {
  ShieldSegmentSparks({
    required Vector2 start,
    required Vector2 end,
    required this.glowColor,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    _emitBurst(start, end);
  }

  static const int sparkCount = 18;

  final Color glowColor;
  final math.Random _random;
  final List<_ShieldSegmentSpark> _sparks = [];
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final Paint _corePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.2;

  int get activeSparkCount => _sparks.length;

  bool get isFinished => _sparks.isEmpty;

  List<Vector2> get sparkPositions => List<Vector2>.unmodifiable(
    _sparks.map((spark) => spark.position.clone()),
  );

  void _emitBurst(Vector2 start, Vector2 end) {
    for (var i = 0; i < sparkCount; i++) {
      final alongSegment = _random.nextDouble();
      final position = start + (end - start) * alongSegment;
      final outward = position.normalized();
      final tangent = Vector2(-outward.y, outward.x);
      final jitter = (_random.nextDouble() - 0.5) * 0.8;
      final direction = (outward + tangent * jitter).normalized();
      final speed = 75 + _random.nextDouble() * 55;
      final lifetime = 0.2 + _random.nextDouble() * 0.18;

      _sparks.add(
        _ShieldSegmentSpark(
          position: position,
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
      _glowPaint.color = glowColor.withValues(alpha: 0.6 * progress);
      _corePaint.color = Color.lerp(
        Colors.white,
        glowColor,
        1 - progress,
      )!.withValues(alpha: progress);

      final end = spark.position.toOffset();
      final start = (spark.position - spark.direction * 3.5).toOffset();
      canvas.drawLine(start, end, _glowPaint);
      canvas.drawLine(start, end, _corePaint);
    }
  }
}

class _ShieldSegmentSpark {
  _ShieldSegmentSpark({
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
