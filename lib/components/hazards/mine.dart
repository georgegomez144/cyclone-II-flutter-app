import 'dart:math' as math;

import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:cyclone_game/game/audio_manager.dart';

/// Spark mine that slowly moves around and homes toward the player's ship.
/// It can get caught on the enemy's shield rings and orbit until it finds
/// an opening. On touching the ship, it damages shields by 25% and
/// destroys the ship when shields deplete to 0.
class SparkMine extends SpriteComponent
    with CollisionCallbacks, HasGameRef<CycloneGame> {
  SparkMine({Vector2? start})
    : super(size: Vector2.all(14), anchor: Anchor.center) {
    if (start != null) {
      position = start.clone();
    }
  }

  // Movement tuning
  final double maxSpeed = 100; // px/sec
  final double accel = 50; // px/sec^2
  final double orbitSpeed = 60; // px/sec along ring
  final double shipHitRadius = 12; // reduced with size
  Vector2 _velocity = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('spark_mine_sprite.png');
    // Add a passive hitbox so player bullets can collide with and destroy the mine
    add(
      CircleHitbox.relative(0.9, parentSize: size)
        ..collisionType = CollisionType.active,
    );

    // Quiet periodic buzzing while the mine is active
    add(
      TimerComponent(
        period: 1.6,
        repeat: true,
        onTick: () {
          AudioManager.instance.playMineBuzz();
        },
      ),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerBullet) {
      if (other.consumed || other.isRemoving) return;
      other.consumed = true;
      other.removeFromParent();
      // Award points for destroying a mine
      gameRef.gm.addScore(20);
      // SFX: mine destroyed
      AudioManager.instance.playMineExplode();
      // Small spark effect and destroy the mine
      final spark = _SparkEffect()..position = position.clone();
      gameRef.add(spark);
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;

    // Difficulty multipliers
    final diff = gameRef.gm.difficulty.value;
    final int level = gameRef.gm.currentLevel.value;
    final double mul = switch (diff) {
      Difficulty.boring => 0.7,
      Difficulty.challenging => 1.0,
      Difficulty.frustrating => 1.5,
    };
    // Level-based scaling: faster tracking each level in frustrating, slight in challenging,
    // slower in boring (the opposite).
    double levelMul;
    switch (diff) {
      case Difficulty.boring:
        levelMul = math
            .pow(0.97, (level - 1).clamp(0, 999))
            .toDouble(); // down to ~0.6 cap
        levelMul = levelMul.clamp(0.6, 1.0);
        break;
      case Difficulty.challenging:
        levelMul = math.pow(1.02, (level - 1).clamp(0, 999)).toDouble();
        levelMul = levelMul.clamp(1.0, 1.6);
        break;
      case Difficulty.frustrating:
        levelMul = math.pow(1.05, (level - 1).clamp(0, 999)).toDouble();
        levelMul = levelMul.clamp(1.0, 2.0);
        break;
    }
    final double dMaxSpeed = maxSpeed * mul * levelMul;
    final double dAccel = accel * mul * levelMul;
    final double dOrbit = orbitSpeed * mul * levelMul;

    // If enemy exists and we are near any of its shield rings, orbit around
    final enemy = gameRef.enemy;
    bool orbited = false;
    if (enemy != null && enemy.isMounted) {
      final toEnemy = position - enemy.position;
      final dist = toEnemy.length;
      // Approx ring radii from enemy shield_system setup (match EnemySprite)
      final rYellow = enemy.size.x * 1.15;
      final rOrange = rYellow * 1.35;
      final rRed = rOrange * 1.25;
      final radii = [rYellow, rOrange, rRed];
      for (final r in radii) {
        if ((dist - r).abs() < 10) {
          // If the mine is roughly aligned with the player from the enemy center,
          // detach and pursue the player instead of continuing to orbit.
          final player = gameRef.player;
          if (player.isMounted) {
            final toPlayerFromEnemy = (player.position - enemy.position)
                .normalized();
            final radial = toEnemy.normalized();
            final cosAngle = toPlayerFromEnemy.dot(radial).clamp(-1.0, 1.0);
            final angleDiff = math.acos(cosAngle); // 0..pi
            if (angleDiff < math.pi / 12) {
              // ~15 degrees alignment
              // Skip orbiting this frame so we can home toward the player
              continue;
            }
          }
          // close to ring path -> ride along tangentially
          final tangential = Vector2(-toEnemy.y, toEnemy.x).normalized();
          position += tangential * dOrbit * dt;
          orbited = true;
          break;
        }
      }
    }

    // If not orbiting, apply gentle homing toward player
    if (!orbited) {
      final player = gameRef.player;
      if (player.isMounted) {
        final desired = (player.position - position).normalized();
        _velocity += desired * dAccel * dt;
        final speed = _velocity.length;
        if (speed > dMaxSpeed) {
          _velocity = _velocity.normalized() * dMaxSpeed;
        }
        position += _velocity * dt;
      }
    }

    // Spin slowly for effect
    angle += 1.0 * dt;

    // Screen clamp (bounce softly)
    final s = gameRef.size;
    if (position.x < 0) position.x = 0;
    if (position.x > s.x) position.x = s.x;
    if (position.y < 0) position.y = 0;
    if (position.y > s.y) position.y = s.y;

    // Check collision with player via distance
    _checkHitPlayer();
  }

  void _checkHitPlayer() {
    final player = gameRef.player;
    if (!player.isMounted) return;
    final d = position.distanceTo(player.position);
    if (d <= shipHitRadius) {
      _applyMineDamage(gameRef.gm);
      // SFX: mine exploded on player
      AudioManager.instance.playMineExplode();
      // Small explosion flash
      final spark = _SparkEffect()..position = position.clone();
      gameRef.add(spark);
      removeFromParent();
    }
  }

  void _applyMineDamage(GameManager gm) {
    // 25% shield damage; if shields reach 0, destroy ship
    final before = gm.shields.value;
    gm.damageShield(25);
    if (before <= 0 || gm.shields.value <= 0) {
      // trigger ship destruction
      gameRef.onPlayerHit();
      // Refill shield for next life
      gm.refillShield(100);
    }
  }
}

class _SparkEffect extends PositionComponent {
  double _t = 0;
  final double duration = 0.35;

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = Colors.orangeAccent;
    final r = (1 - (_t / duration)) * 18;
    canvas.drawCircle(Offset.zero, r, p);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= duration) removeFromParent();
  }
}
