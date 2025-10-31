import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/components/enemy/enemy_sprite.dart';
import 'package:cyclone_game/components/effects/explosion.dart';
import 'package:cyclone_game/components/pickups/yummy_pickup.dart';
import 'package:cyclone_game/game/audio_manager.dart';

/// Simple player bullet that flies straight with a lifetime and screen wrap
class PlayerBullet extends PositionComponent
    with CollisionCallbacks, HasGameRef<CycloneGame> {
  PlayerBullet({required this.velocity, required this.onDespawn})
    : super(size: Vector2.all(6), anchor: Anchor.center);

  final Vector2 velocity;
  final VoidCallback onDespawn;
  final double speed = 800; // px/sec magnitude of velocity vector
  double lifetime = 1.5; // seconds

  // Internal flag to prevent multiple collisions in the same frame
  bool consumed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox()..collisionType = CollisionType.active);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.yellow.shade50;
    canvas.drawCircle(Offset.zero, size.x / 2, paint);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move forward
    position += velocity.normalized() * speed * dt;

    // Screen wrap-around (like the player)
    final s = gameRef.size;
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    if (position.x < -halfW) position.x = s.x + halfW;
    if (position.x > s.x + halfW) position.x = -halfW;
    if (position.y < -halfH) position.y = s.y + halfH;
    if (position.y > s.y + halfH) position.y = -halfH;

    // Lifetime countdown
    lifetime -= dt;
    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    // If this bullet has already been consumed by a shield segment, ignore.
    if (consumed || isRemoving) return;
    if (other is EnemySprite) {
      // Only destroy enemy if there are aligned gaps through all rings
      final canHitCore = other.hasAlignedGapsToward(position);
      if (canHitCore) {
        // Spawn explosion at enemy position
        final boom = Explosion()..position = other.position.clone();
        gameRef.add(boom);
        // Notify game of victory and remove enemy
        gameRef.onEnemyDefeated();
        // Despawn this bullet
        consumed = true;
        removeFromParent();
      } else {
        // Otherwise, the shield should intercept the bullet; do nothing here.
      }
    } else if (other is YummyPickup) {
      // Player bullets can destroy yummies; do not grant their effect.
      if (!other.isRemoving) {
        // SFX: yummy destroyed / discarded by shot
        AudioManager.instance.playYummyDiscard();
        other.removeFromParent();
      }
      consumed = true;
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    onDespawn();
    super.onRemove();
  }
}
