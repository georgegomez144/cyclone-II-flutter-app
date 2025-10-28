import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

import 'package:cyclone_game/game/game_manager.dart';

/// Simple player bullet that flies straight with a lifetime
class PlayerBullet extends PositionComponent with CollisionCallbacks {
  PlayerBullet({required this.velocity, required this.onDespawn})
    : super(size: Vector2.all(6), anchor: Anchor.center);

  final Vector2 velocity;
  final VoidCallback onDespawn;
  final double speed = 520; // px/sec magnitude of velocity vector
  double lifetime = 1.6; // seconds

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox()..collisionType = CollisionType.active);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset.zero, size.x / 2, paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity.normalized() * speed * dt;
    lifetime -= dt;
    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    onDespawn();
    super.onRemove();
  }
}
