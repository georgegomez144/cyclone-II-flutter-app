import 'dart:math' as math;

import 'package:cyclone_game/components/effects/explosion.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Enemy blast uses sprite asset with an orange/red glow.
class EnemyBlast extends SpriteComponent with HasGameRef<CycloneGame> {
  EnemyBlast({
    required this.start,
    required this.direction,
    this.baseSpeed = 300.0,
    this.growthFactorPerSecond = 1.5,
    this.initialSize = const Size(22, 22),
    this.spinSpeed = 6.0, // radians/sec (used for subtle flicker rotation)
  }) : super(anchor: Anchor.center);

  final Vector2 start;
  final Vector2 direction; // normalized
  final double baseSpeed; // px/sec
  final double growthFactorPerSecond; // multiplicative scale per second
  final Size initialSize;
  final double spinSpeed; // radians/sec

  late final Vector2 _vel;
  double _scale = 1.0;
  double _t = 0.0;
  bool _hitApplied = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = start.clone();
    size = Vector2(initialSize.width, initialSize.height);
    _vel = direction.normalized() * baseSpeed;
    // Load sprite from assets (Flame images prefix set to 'assets/' in game)
    sprite = await Sprite.load('enemy_blast.png');
  }

  @override
  void render(Canvas canvas) {
    // Draw soft orange/red bloom behind the sprite
    final radius = (size.x * _scale) / 2;
    final center = Offset.zero;
    final bloomPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 24)
      ..color = Colors.deepOrange.withOpacity(0.6);
    canvas.drawCircle(center, radius * 1.25, bloomPaint);

    // Optional inner warm glow to intensify color
    final innerGlow = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = Colors.orangeAccent.withOpacity(0.35);
    canvas.drawCircle(center, radius * 0.9, innerGlow);

    // Now draw the sprite itself centered via SpriteComponent's render
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;

    // Move forward
    position += _vel * dt;

    // Subtle spin
    angle += spinSpeed * 0.2 * dt;

    // Exponential growth of scale
    if (dt > 0) {
      _scale *= math.pow(growthFactorPerSecond, dt).toDouble();
      scale = Vector2.all(_scale);
    }

    // Off-screen culling
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
          color: Colors.deepOrangeAccent,
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
