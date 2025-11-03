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
  Starfield({required this.sizeProvider, int? count}) : _explicitCount = count;
  final int? _explicitCount;
  final Vector2 Function() sizeProvider;
  final math.Random _rng = math.Random();
  Vector2? _lastSize;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _rebuildForSize(sizeProvider());
  }

  int _computeCount(Vector2 size) {
    if (_explicitCount != null) return _explicitCount!;
    // Adaptive density based on screen area; keep uncluttered
    final area = size.x * size.y;
    final target = (area * 0.00003).clamp(60, 120).toInt();
    return target;
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    // Rebuild starfield only when size actually changes
    if (_lastSize == null ||
        _lastSize!.x != gameSize.x ||
        _lastSize!.y != gameSize.y) {
      _rebuildForSize(gameSize);
    }
  }

  /// Randomize star positions within the current game size.
  void randomize() {
    final size = sizeProvider();
    _rebuildForSize(size);
  }

  void _rebuildForSize(Vector2 size) {
    _lastSize = size.clone();
    // Remove any existing stars
    final existing = children.whereType<Star>().toList(growable: false);
    if (existing.isNotEmpty) {
      removeAll(existing);
    }
    // Spawn stars within the new bounds
    final count = _computeCount(size);
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
