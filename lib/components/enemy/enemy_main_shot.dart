import 'dart:math' as math;

import 'package:cyclone_game/components/effects/explosion.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A short-lived massive beam from the enemy core towards the player.
/// Fires only when triggered by EnemyCore after confirming openings.
class EnemyMainShot extends PositionComponent with HasGameRef<CycloneGame> {
  EnemyMainShot({required this.start, required this.end, this.duration = 0.45})
    : super(anchor: Anchor.center);

  final Vector2 start;
  final Vector2 end;
  final double duration;

  double _time = 0;
  bool _hitApplied = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = start.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_time >= duration) {
      removeFromParent();
      return;
    }

    // Check collision vs player by distance from line segment
    final player = gameRef.player;
    final p = player.position;
    final dist = _distancePointToSegment(p, start, end);
    // Consider player's approx radius
    final playerRadius = player.size.length / 4; // ~13
    if (!_hitApplied && dist <= playerRadius) {
      _hitApplied = true;
      // Fatal hit: destroy player's ship (one hit)
      final explosion = Explosion(
        color: Colors.redAccent,
        maxRadius: 48,
        duration: 0.5,
      )..position = player.position.clone();
      gameRef.add(explosion);
      // Delegate life/respawn handling to game
      gameRef.onPlayerHit();
    }
  }

  @override
  void render(Canvas canvas) {
    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.cyanAccent.withOpacity(0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);
    final telePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = Colors.white.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 16);

    final p0 = Offset(start.x, start.y);
    final p1 = Offset(end.x, end.y);
    canvas.drawLine(p0, p1, telePaint);
    canvas.drawLine(p0, p1, pathPaint);
  }

  // Helpers
  static double _distancePointToSegment(Vector2 p, Vector2 a, Vector2 b) {
    final ap = p - a;
    final ab = b - a;
    final ab2 = ab.x * ab.x + ab.y * ab.y;
    final t = (ap.x * ab.x + ap.y * ab.y) / (ab2 == 0 ? 1e-6 : ab2);
    final clampedT = t.clamp(0.0, 1.0) as double;
    final closest = a + ab * clampedT;
    return (p - closest).length;
  }
}
