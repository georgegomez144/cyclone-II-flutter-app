import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Simple starfield rendering random dots to simulate space.
class Star extends PositionComponent {
  Star({required this.velocity}) : super(size: Vector2.all(1));
  final Vector2 velocity;
  double alpha = 0.4 + math.Random().nextDouble() * 0.6; // 0.4..1.0

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.amber.withOpacity(alpha);
    canvas.drawRect(Offset.zero & const Size(2, 2), paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
  }
}

class Starfield extends Component with HasGameRef {
  Starfield({required this.sizeProvider, this.count = 140});
  final int count;
  final Vector2 Function() sizeProvider;
  final math.Random _rng = math.Random();
  final List<Star> _stars = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spawnInitial();
  }

  void _spawnInitial() {
    final size = sizeProvider();
    for (int i = 0; i < count; i++) {
      final pos = Vector2(
        _rng.nextDouble() * size.x,
        _rng.nextDouble() * size.y,
      );
      final speed = 6 + _rng.nextDouble() * 24; // slow drift
      final dir = Vector2(
        _rng.nextDouble() - 0.5,
        _rng.nextDouble() - 0.5,
      ).normalized();
      final star = Star(velocity: dir * speed)..position = pos;
      _stars.add(star);
      add(star);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final size = sizeProvider();
    for (final s in _stars) {
      // wrap around screen
      if (s.position.x < -2) s.position.x = size.x + 2;
      if (s.position.y < -2) s.position.y = size.y + 2;
      if (s.position.x > size.x + 2) s.position.x = -2;
      if (s.position.y > size.y + 2) s.position.y = -2;
    }
  }
}
