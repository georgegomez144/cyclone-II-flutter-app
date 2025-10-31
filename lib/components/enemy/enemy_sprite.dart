import 'dart:math' as math;
import 'dart:ui';

import 'package:cyclone_game/components/enemy/enemy_blast.dart';
import 'package:cyclone_game/components/enemy/shield_system.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/utils.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:cyclone_game/game/audio_manager.dart';

/// Simple enemy ship sprite pinned to the center of the screen.
/// - Slowly turns to track the player with a capped turn rate that
///   increases slightly with level.
/// - Randomly fires a sprite-based blast toward the player with a
///   minimum interval of 5 seconds between shots.
class EnemySprite extends SpriteComponent with HasGameRef<CycloneGame> {
  EnemySprite() : super(size: Vector2.all(60), anchor: Anchor.center);

  EnemyShield? _shield;

  // Turning/aiming
  final double _baseTurnRate = 0.8; // rad/sec at level 1 (pretty slow)
  final double _turnRatePerLevel = 0.02; // small increase per level

  // Firing control
  double _cooldown = 0.0;
  final double fireCooldown = 0.7; // seconds between shots when openings appear

  VoidCallback? _levelListener;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('enemy_sprite.png');
    // Start centered
    position = gameRef.size / 2;

    // Add a circular hitbox for collisions with player bullets
    add(
      CircleHitbox.relative(0.7, parentSize: size)
        ..collisionType = CollisionType.passive,
    );

    // Install shield system using the existing visual radii
    final double rYellow = size.x * (isPhone ? 1 : 1.3);
    final double rOrange = rYellow * 1.35;
    final double rRed = rOrange * 1.25;
    _shield = EnemyShield(
      yellowRadius: rYellow,
      orangeRadius: rOrange,
      redRadius: rRed,
      strokeWidth: 4,
    )..position = Vector2(size.x / 2, size.y / 2);
    add(_shield!);

    // Reset shields on level change only
    _levelListener = () {
      _shield?.resetAll();
    };
    gameRef.gm.currentLevel.addListener(_levelListener!);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Keep enemy pinned in center on resize
    position = gameRef.size / 2;
    // Shield stays centered because it's a child at (size/2)
  }

  @override
  void update(double dt) {
    super.update(dt);

    // TURNING: lag behind player's position using capped angular velocity
    final player = gameRef.player;
    if (player.isMounted) {
      final toPlayer = (player.position - position);
      if (toPlayer.length2 > 0) {
        final desired = math.atan2(toPlayer.y, toPlayer.x) + math.pi / 2;
        final current = angle;
        var delta = _wrapAngle(desired - current);
        final level = gameRef.gm.currentLevel.value;
        var turnRate =
            _baseTurnRate + _turnRatePerLevel * (level - 1).clamp(0, 999);
        // Difficulty scaling: boring < challenging < frustrating
        final diff = gameRef.gm.difficulty.value;
        final diffMul = switch (diff) {
          Difficulty.boring => 0.7,
          Difficulty.challenging => 1.0,
          Difficulty.frustrating => 1.6,
        };
        turnRate *= diffMul;
        final maxStep = turnRate * dt;
        if (delta.abs() > maxStep) {
          delta = delta.sign * maxStep;
        }
        angle = current + delta;
      }
    }

    // FIRING: only from the front arc and when an opening across all rings aligns
    if (_cooldown > 0) {
      _cooldown -= dt;
    }
    if (_cooldown <= 0 && player.isMounted) {
      final throughOpening =
          _shield?.canFireTowardGlobal(position, player.position) ?? false;
      final inFront = _isInFrontCone(player.position);
      if (throughOpening && inFront) {
        _fireAtPlayer();
        _cooldown = fireCooldown;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Visual rings are now rendered by EnemyShield child component.
  }

  // Check whether a world point is within the enemy's forward firing cone.
  // Front is along local -Y rotated by current angle. Half-angle ~45 degrees.
  bool _isInFrontCone(Vector2 worldPoint, {double halfAngle = math.pi / 4}) {
    final toPoint = (worldPoint - position);
    if (toPoint.length2 == 0) return false;
    final fwd = Vector2(0, -1)..rotate(angle);
    final cosTheta = (fwd.dot(toPoint.normalized())).clamp(-1.0, 1.0);
    final theta = math.acos(cosTheta);
    return theta <= halfAngle;
  }

  void _fireAtPlayer() {
    final player = gameRef.player;
    if (!player.isMounted) return;

    // Only fire if there are aligned gaps across all rings toward the player
    final canShoot =
        _shield?.canFireTowardGlobal(position, player.position) ?? false;
    if (!canShoot) return;

    // And only if target is within the front cone relative to enemy facing
    if (!_isInFrontCone(player.position)) return;

    // Compute world-space firing direction toward the player, but spawn from the enemy sprite's nose
    final dir = (player.position - position).normalized();
    final Vector2 fwd = Vector2(0, -1)..rotate(angle);
    final double spawnDist = (size.y / 2) + 6.0; // just ahead of the sprite tip
    final Vector2 startPos = position + fwd * spawnDist;

    // SFX: enemy blast fired
    AudioManager.instance.playEnemyBlast();

    final blast = EnemyBlast(
      start: startPos,
      direction: dir,
      baseSpeed: 360.0, // modest speed to allow dodging early on
      growthFactorPerSecond: 1.5,
      initialSize: Size(18, 18),
    );
    gameRef.add(blast);
  }

  bool hasAlignedGapsToward(Vector2 worldPoint) {
    return _shield?.canFireTowardGlobal(position, worldPoint) ?? false;
  }

  @override
  void onRemove() {
    // Clean listener
    if (_levelListener != null) {
      gameRef.gm.currentLevel.removeListener(_levelListener!);
      _levelListener = null;
    }
    super.onRemove();
  }

  static double _wrapAngle(double a) {
    while (a <= -math.pi) a += 2 * math.pi;
    while (a > math.pi) a -= 2 * math.pi;
    return a;
  }
}
