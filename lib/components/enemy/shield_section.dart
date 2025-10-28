import 'dart:math' as math;

import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// One wedge-shaped shield section.
/// States: 2 (healthy) -> 1 (weakened/faded) -> 0 (destroyed; gap).
class ShieldSection extends PositionComponent
    with CollisionCallbacks, HasGameRef<CycloneGame> {
  ShieldSection({
    required this.radiusInner,
    required this.radiusOuter,
    required this.angleStart,
    required this.angleEnd,
    required this.color,
  }) : super(anchor: Anchor.center);

  final double radiusInner;
  final double radiusOuter;
  final double angleStart; // radians
  final double angleEnd; // radians
  final Color color;

  int hp = 2;
  late final PolygonHitbox _hitbox;

  bool get isDestroyed => hp <= 0;
  bool get isWeakened => hp == 1;

  /// Build the wedge polygon in local space around (0,0) center.
  List<Vector2> _buildPolygon() {
    // Approximate wedge with inner and outer arc points (2 points each)
    final p = <Vector2>[];
    p.add(Vector2(math.cos(angleStart), math.sin(angleStart)) * radiusOuter);
    p.add(Vector2(math.cos(angleEnd), math.sin(angleEnd)) * radiusOuter);
    p.add(Vector2(math.cos(angleEnd), math.sin(angleEnd)) * radiusInner);
    p.add(Vector2(math.cos(angleStart), math.sin(angleStart)) * radiusInner);
    return p;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(radiusOuter * 2);
    _hitbox = PolygonHitbox(_buildPolygon())
      ..collisionType = CollisionType.passive;
    add(_hitbox);
  }

  @override
  void render(Canvas canvas) {
    // Render as a glowing 8px stroked arc (solid line section). Destroyed => gap
    if (isDestroyed) return; // gap

    final midR = (radiusInner + radiusOuter) / 2;
    final sweep = angleEnd - angleStart;

    // Outer glow behind
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(isWeakened ? 0.25 : 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);

    // Main stroke
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(isWeakened ? 0.6 : 0.95);

    final arcRect = Rect.fromCircle(center: Offset.zero, radius: midR);

    canvas.drawArc(arcRect, angleStart, sweep, false, glow);
    canvas.drawArc(arcRect, angleStart, sweep, false, stroke);
  }

  void regenerate() {
    hp = 2;
    _hitbox.collisionType = CollisionType.passive;
  }

  void _applyDamageFromBullet(PlayerBullet bullet) {
    if (isDestroyed) {
      // Already a gap; let bullet pass through (do nothing)
      return;
    }
    hp -= 1;
    // Remove bullet either way (hit consumed)
    bullet.removeFromParent();

    if (isDestroyed) {
      // Deactivate collisions so future bullets pass through
      _hitbox.collisionType = CollisionType.inactive;
      // Score: +1 per destroyed ring section
      gameRef.gm.addScore(1);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlayerBullet) {
      _applyDamageFromBullet(other);
    }
  }
}
