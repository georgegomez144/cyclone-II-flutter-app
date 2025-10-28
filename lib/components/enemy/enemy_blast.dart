import 'dart:math' as math;

import 'package:cyclone_game/components/effects/explosion.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A sprite-based enemy blast projectile that starts small and
/// grows by 1.5x over time until it goes off-screen or hits the player.
class EnemyBlast extends SpriteComponent with HasGameRef<CycloneGame> {
  EnemyBlast({
    required this.start,
    required this.direction,
    this.baseSpeed = 220.0,
    this.growthFactorPerSecond = 1.5,
    this.initialSize = const Size(22, 22),
  }) : super(anchor: Anchor.center);

  final Vector2 start;
  final Vector2 direction; // normalized
  final double baseSpeed; // px/sec
  final double growthFactorPerSecond; // multiplicative scale per second
  final Size initialSize;

  late final Vector2 _vel;
  double _scale = 1.0;
  bool _hitApplied = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('enemy_blast.png');
    position = start.clone();
    size = Vector2(initialSize.width, initialSize.height);
    _vel = direction.normalized() * baseSpeed;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move forward
    position += _vel * dt;

    // Exponential growth of scale: 1.5x per second
    if (dt > 0) {
      _scale *= math.pow(growthFactorPerSecond, dt).toDouble();
      scale = Vector2.all(_scale);
    }

    // Off-screen culling (when fully off with small margin)
    final s = gameRef.size;
    final halfW = (size.x * _scale) / 2;
    final halfH = (size.y * _scale) / 2;
    const margin = 32.0;
    if (position.x < -halfW - margin ||
        position.x > s.x + halfW + margin ||
        position.y < -halfH - margin ||
        position.y > s.y + halfH + margin) {
      removeFromParent();
      return;
    }

    // Collision vs player: distance threshold using player's approx radius
    final player = gameRef.player;
    if (player.isMounted) {
      final dist = position.distanceTo(player.position);
      final blastRadius = math.max(halfW, halfH) * 0.8; // generous a bit
      final playerRadius = player.size.length / 4; // ~13
      if (!_hitApplied && dist <= blastRadius + playerRadius) {
        _hitApplied = true;
        final explosion = Explosion(
          color: Colors.redAccent,
          maxRadius: 48,
          duration: 0.5,
        )..position = player.position.clone();
        gameRef.add(explosion);
        // Delegate life/respawn handling to game
        gameRef.onPlayerHit();
        removeFromParent();
      }
    }
  }
}
