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
  final double _baseTurnRate = 0.8; // rad/sec at level 1 (pretty slow)
  final double _turnRatePerLevel = 0.02; // small increase per level

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

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw a 12-sided glowing yellow ring around the enemy (4px thick)
    // Ensure the ring is centered on the sprite's anchor (component center)
    const int sides = 12;
    final double r = size.x * 1.4; // slightly larger than sprite center

    canvas.save();
    // Translate local origin (top-left) to component center so the ring is centered
    canvas.translate(size.x / 2, size.y / 2);

    // Outer red ring (25% larger than orange)
    final double rOuter = r * 1.35; // orange radius
    final double rRed = rOuter * 1.25; // red radius = r * 1.5625

    final Path redRingPath = Path();
    for (int i = 0; i < sides; i++) {
      final double theta = (i / sides) * math.pi * 2 - math.pi / 2; // start top
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
      ..color = const Color(0xFFFF0000)
          .withOpacity(0.9) // red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final Paint redRingPaint = Paint()
      ..color =
          const Color(0xFFFF0000) // red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Outer orange ring (25% larger than yellow)
    final Path outerRingPath = Path();
    for (int i = 0; i < sides; i++) {
      final double theta = (i / sides) * math.pi * 2 - math.pi / 2; // start top
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
      ..color = const Color(0xFFFFA500)
          .withOpacity(0.9) // orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final Paint outerRingPaint = Paint()
      ..color =
          const Color(0xFFFFA500) // orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Inner yellow ring (original)
    final Path ringPath = Path();
    for (int i = 0; i < sides; i++) {
      final double theta = (i / sides) * math.pi * 2 - math.pi / 2; // start top
      final double x = r * math.cos(theta);
      final double y = r * math.sin(theta);
      if (i == 0) {
        ringPath.moveTo(x, y);
      } else {
        ringPath.lineTo(x, y);
      }
    }
    ringPath.close();

    final Paint glowPaint = Paint()
      ..color = const Color(0xFFFFFF00)
          .withOpacity(0.95) // yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final Paint ringPaint = Paint()
      ..color = const Color(0xFFFFFF00)
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

  void _fireAtPlayer() {
    final player = gameRef.player;
    if (!player.isMounted) return;
    final dir = (player.position - position).normalized();
    final blast = EnemyBlast(
      start: position.clone(),
      direction: dir,
      baseSpeed: 360.0, // modest speed to allow dodging early on
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
