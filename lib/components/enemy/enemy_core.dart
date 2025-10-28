import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/enemy_main_shot.dart';
import 'package:cyclone_game/components/enemy/shield_ring.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Enemy core ship that sits in the center with three shield rings.
/// It spins at center to aim at the player and can fire a massive
/// blast ONLY when there is a continuous opening through all three rings
/// along the line to the player.
class EnemyCore extends PositionComponent
    with HasGameRef<CycloneGame>, CollisionCallbacks {
  EnemyCore({
    required this.innerRadius,
    required this.middleRadius,
    required this.outerRadius,
  }) : super(size: Vector2.all(36), anchor: Anchor.center);

  final double innerRadius; // outer of inner ring
  final double middleRadius; // outer of middle ring
  final double outerRadius; // outer of outer ring

  late final ShieldRing ringInner;
  late final ShieldRing ringMiddle;
  late final ShieldRing ringOuter;

  // Spin speeds for rings (rad/sec)
  final double outerSpin = 0.6; // clockwise
  final double middleSpin = -0.9; // counter-clockwise
  final double innerSpin = 1.2; // clockwise

  // Firing control
  double _cooldown = 0;
  final double fireCooldown = 2.5; // seconds between massive shots

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Build rings as children so they move with the core
    ringOuter = ShieldRing(
      index: RingIndex.outer,
      radiusInner: outerRadius - 28,
      radiusOuter: outerRadius,
      color: Colors.redAccent,
    )..angularSpeed = outerSpin;
    ringMiddle = ShieldRing(
      index: RingIndex.middle,
      radiusInner: middleRadius - 28,
      radiusOuter: middleRadius,
      color: Colors.orangeAccent,
    )..angularSpeed = middleSpin;
    ringInner = ShieldRing(
      index: RingIndex.inner,
      radiusInner: innerRadius - 28,
      radiusOuter: innerRadius,
      color: Colors.yellowAccent,
    )..angularSpeed = innerSpin;

    await addAll([ringOuter, ringMiddle, ringInner]);

    // Add a circular hitbox for bullet collision
    add(
      CircleHitbox.relative(0.9, parentSize: size)
        ..collisionType = CollisionType.passive,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Keep core in the center; rotate to face the player
    final toPlayer = gameRef.player.position - position;
    if (toPlayer.length2 > 1e-3) {
      angle =
          math.atan2(toPlayer.y, toPlayer.x) +
          math.pi / 2; // triangle points up
    }

    // Cooldown timer
    if (_cooldown > 0) _cooldown -= dt;

    // Attempt to fire if clear line through all rings
    if (_cooldown <= 0) {
      final dir = (gameRef.player.position - position);
      if (dir.length2 > 1) {
        final angleToPlayer = math.atan2(dir.y, dir.x);
        final open =
            ringInner.isOpenAtAngle(angleToPlayer) &&
            ringMiddle.isOpenAtAngle(angleToPlayer) &&
            ringOuter.isOpenAtAngle(angleToPlayer);
        if (open) {
          _fireMassiveShot(dir.normalized());
          _cooldown = fireCooldown;
        }
      }
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Ensure the enemy core remains centered on the screen
    position = gameRef.size / 2;
  }

  void _fireMassiveShot(Vector2 dir) {
    final start = position.clone();
    // End far beyond screen in direction of player
    final maxSide = gameRef.size.length; // rough max distance
    final end = start + dir * (maxSide + 600);
    gameRef.add(EnemyMainShot(start: start, end: end));
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerBullet) {
      // Only allow kill if the bullet line comes through gaps across all three rings
      final angleToBullet = math.atan2(
        other.position.y - position.y,
        other.position.x - position.x,
      );
      final open =
          ringInner.isOpenAtAngle(angleToBullet) &&
          ringMiddle.isOpenAtAngle(angleToBullet) &&
          ringOuter.isOpenAtAngle(angleToBullet);
      // Remove bullet on contact either way
      other.removeFromParent();
      if (open) {
        gameRef.gm.addScore(100);
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Render a glowing central enemy ship (triangle)
    final hull = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    final stroke = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final w = size.x;
    final path = Path()
      ..moveTo(0, -w * 0.6)
      ..lineTo(w * 0.5, w * 0.6)
      ..lineTo(-w * 0.5, w * 0.6)
      ..close();

    canvas.drawPath(path, hull);
    canvas.drawPath(path, stroke);
  }
}
