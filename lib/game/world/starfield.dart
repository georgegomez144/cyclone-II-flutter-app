import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Simple starfield rendering static white dots to simulate space.
class Star extends PositionComponent {
  Star() : super(size: Vector2.all(1));
  double alpha = 0.6 + math.Random().nextDouble() * 0.4; // 0.6..1.0

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.white.withOpacity(alpha);
    canvas.drawRect(Offset.zero & const Size(2, 2), paint);
  }
}

class Starfield extends Component with HasGameRef {
  Starfield({required this.sizeProvider, this.count = 140});
  final int count;
  final Vector2 Function() sizeProvider;
  final math.Random _rng = math.Random();

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
      final star = Star()..position = pos;
      add(star);
    }
  }
}
