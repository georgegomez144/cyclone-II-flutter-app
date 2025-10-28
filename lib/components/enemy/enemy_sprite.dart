import 'dart:math' as math;
import 'dart:ui';

import 'package:cyclone_game/components/enemy/enemy_blast.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// Simple enemy ship sprite pinned to the center of the screen.
/// - Slowly turns to track the player with a capped turn rate that
///   increases slightly with level.
/// - Randomly fires a sprite-based blast toward the player with a
///   minimum interval of 5 seconds between shots.
class EnemySprite extends SpriteComponent with HasGameRef<CycloneGame> {
  EnemySprite() : super(size: Vector2.all(60), anchor: Anchor.center);

  // Turning/aiming
  final double _baseTurnRate = 0.7; // rad/sec at level 1 (pretty slow)
  final double _turnRatePerLevel = 0.08; // small increase per level

  // Firing control
  final math.Random _rnd = math.Random();
  double _timeUntilNextShot = 0.0;

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

    _resetShotTimer();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Keep enemy pinned in center on resize
    position = gameRef.size / 2;
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
        final turnRate =
            _baseTurnRate + _turnRatePerLevel * (level - 1).clamp(0, 999);
        final maxStep = turnRate * dt;
        if (delta.abs() > maxStep) {
          delta = delta.sign * maxStep;
        }
        angle = current + delta;
      }
    }

    // FIRING: randomized intervals with a minimum of 5 seconds between shots
    if (_timeUntilNextShot > 0) {
      _timeUntilNextShot -= dt;
    }
    if (_timeUntilNextShot <= 0) {
      _fireAtPlayer();
      _resetShotTimer();
    }
  }

  void _fireAtPlayer() {
    final player = gameRef.player;
    if (!player.isMounted) return;
    final dir = (player.position - position).normalized();
    final blast = EnemyBlast(
      start: position.clone(),
      direction: dir,
      baseSpeed: 240.0, // modest speed to allow dodging early on
      growthFactorPerSecond: 1.5,
      initialSize: Size(18, 18),
    );
    gameRef.add(blast);
  }

  void _resetShotTimer() {
    // Minimum 5s, plus up to ~5s randomness
    _timeUntilNextShot = 5.0 + _rnd.nextDouble() * 5.0;
  }

  static double _wrapAngle(double a) {
    while (a <= -math.pi) a += 2 * math.pi;
    while (a > math.pi) a -= 2 * math.pi;
    return a;
  }
}
