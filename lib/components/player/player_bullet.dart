import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/components/enemy/shield_fire_solver.dart';
import 'package:cyclone_game/components/player/player_bullet_sweep.dart';
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
    if (consumed || isRemoving) return;

    final previousPosition = position.clone();
    position += velocity.normalized() * speed * dt;

    final enemy = gameRef.enemy;
    final shield = enemy?.shield;
    if (enemy != null && enemy.isMounted) {
      final rings = shield != null && shield.isLoaded
          ? [shield.redRing, shield.orangeRing, shield.yellowRing]
                .map(
                  (ring) => ShieldRingSnapshot(
                    outerRadius: ring.outerRadius,
                    innerRadius: ring.innerRadius,
                    angleOffset: ring.angleOffset,
                    angularVelocity: ring.angularVelocity,
                    destroyedSegments: ring.destroyedSegments,
                  ),
                )
                .toList(growable: false)
          : const <ShieldRingSnapshot>[];
      final hit = PlayerBulletSweep.firstHit(
        from: previousPosition,
        to: position,
        center: enemy.position,
        rings: rings,
        bulletRadius: size.x / 2,
        coreRadius: enemy.coreRadius,
      );
      if (hit != null) {
        consumed = true;
        if (hit.isCore) {
          final boom = Explosion()..position = enemy.position.clone();
          gameRef.add(boom);
          gameRef.onEnemyDefeated();
        } else {
          final activeShield = shield!;
          final ring = [
            activeShield.redRing,
            activeShield.orangeRing,
            activeShield.yellowRing,
          ][hit.ringIndex!];
          ring.hitSegment(hit.segmentIndex!);
          gameRef.gm.addScore(5);
        }
        removeFromParent();
        return;
      }
    }

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
    // If the swept collision check already consumed this bullet, ignore it.
    if (consumed || isRemoving) return;
    if (other is YummyPickup) {
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
