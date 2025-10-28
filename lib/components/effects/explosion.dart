import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A quick glow burst explosion that expands and fades out.
class Explosion extends PositionComponent {
  Explosion({this.duration = 0.4, this.maxRadius = 36, Color? color})
    : _color = color ?? Colors.amberAccent,
      super(anchor: Anchor.center, size: Vector2.all(1));

  final double duration;
  final double maxRadius;
  final Color _color;

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_time >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // t: 0..1 progression
    final t = ((_time / duration).clamp(0.0, 1.0)) as double;
    final radius = maxRadius * Curves.easeOut.transform(t);

    // Outer glow
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18.0 * (1.0 - t)
      ..color = _color.withOpacity(0.35 * (1.0 - t))
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 20);

    // Core ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0 * (1.0 - 0.5 * t)
      ..color = Colors.white.withOpacity(0.9 * (1.0 - t));

    canvas.drawCircle(Offset.zero, radius, glow);
    canvas.drawCircle(Offset.zero, radius, ring);
  }
}
