import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/enemy_main_shot.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:cyclone_game/utils.dart';

/// Enemy core ship that sits in the center and fires at the player
/// at intervals when its cooldown allows.
class EnemyCore extends PositionComponent
    with HasGameRef<CycloneGame>, CollisionCallbacks {
  EnemyCore({
    required this.innerRadius,
    required this.middleRadius,
    required this.outerRadius,
  }) : super(size: Vector2.all(isPhone ? 30 : 36), anchor: Anchor.center);

  final double innerRadius; // outer of inner ring
  final double middleRadius; // outer of middle ring
  final double outerRadius; // outer of outer ring

  // Firing control
  double _cooldown = 0;
  final double fireCooldown = 2.5; // seconds between massive shots

  @override
  Future<void> onLoad() async {
    await super.onLoad();

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

    // Attempt to fire toward the player when cooldown allows
    if (_cooldown <= 0) {
      final dir = (gameRef.player.position - position);
      if (dir.length2 > 1) {
        _fireMassiveShot(dir.normalized());
        _cooldown = fireCooldown;
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
      // Remove bullet and destroy the core on hit
      other.removeFromParent();
      gameRef.gm.addScore(100);
      removeFromParent();
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
    final shipPath = Path()
      ..moveTo(0, -w * 0.6)
      ..lineTo(w * 0.5, w * 0.6)
      ..lineTo(-w * 0.5, w * 0.6)
      ..close();

    canvas.drawPath(shipPath, hull);
    canvas.drawPath(shipPath, stroke);

    // Draw a 12-sided glowing yellow ring around the enemy (4px thick)
    const int sides = 12;
    final double r = w * 0.8; // radius slightly larger than the ship

    canvas.save();
    // Translate to component center so the ring anchor matches the sprite position
    canvas.translate(size.x / 2, size.y / 2);

    // Outer red ring (25% larger than orange)
    final double rOuter = r * 1.25; // orange radius
    final double rRed = rOuter * 1.25; // red radius = r * 1.5625

    final Path redRingPath = Path();
    for (int i = 0; i < sides; i++) {
      final double theta =
          (i / sides) * math.pi * 2 - math.pi / 2; // start at top
      final double x = rRed * math.cos(theta);
      final double y = rRed * math.sin(theta);
      if (i == 0) {
        redRingPath.moveTo(x, y);
      } else {
        redRingPath.lineTo(x, y);
      }
    }
    redRingPath.close();

    final Paint redGlowPaint = Paint()
      ..color = Colors.red.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final Paint redRingPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Outer orange ring (25% larger than yellow)
    final Path outerRingPath = Path();
    for (int i = 0; i < sides; i++) {
      final double theta =
          (i / sides) * math.pi * 2 - math.pi / 2; // start at top
      final double x = rOuter * math.cos(theta);
      final double y = rOuter * math.sin(theta);
      if (i == 0) {
        outerRingPath.moveTo(x, y);
      } else {
        outerRingPath.lineTo(x, y);
      }
    }
    outerRingPath.close();

    final Paint outerGlowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final Paint outerRingPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Inner yellow ring (original)
    Path ringPath = Path();
    for (int i = 0; i < sides; i++) {
      final double theta =
          (i / sides) * math.pi * 2 - math.pi / 2; // start at top
      final double x = r * math.cos(theta);
      final double y = r * math.sin(theta);
      if (i == 0) {
        ringPath.moveTo(x, y);
      } else {
        ringPath.lineTo(x, y);
      }
    }
    ringPath.close();

    final glowPaint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final ringPaint = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw order: outermost red → orange → inner yellow (each: glow then stroke)
    canvas.drawPath(redRingPath, redGlowPaint);
    canvas.drawPath(redRingPath, redRingPaint);

    canvas.drawPath(outerRingPath, outerGlowPaint);
    canvas.drawPath(outerRingPath, outerRingPaint);

    canvas.drawPath(ringPath, glowPaint);
    canvas.drawPath(ringPath, ringPaint);

    canvas.restore();
  }
}
