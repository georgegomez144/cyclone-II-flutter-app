import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/cyclone_game.dart';

class Player extends PositionComponent
    with KeyboardHandler, CollisionCallbacks, HasGameRef<CycloneGame> {
  Player({required this.gm})
    : super(size: Vector2(26, 26), anchor: Anchor.center);

  final GameManager gm;

  // Movement
  final double moveSpeed = 280; // px/sec
  Vector2 _move = Vector2.zero();

  // Shooting
  int maxSimultaneousBullets = 1;
  int _activeBullets = 0;
  double _cooldown = 0;
  final double bulletCooldown = 0.18; // seconds

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      CircleHitbox.relative(0.6, parentSize: size)
        ..collisionType = CollisionType.passive,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move
    if (_move.length2 > 0) {
      position += _move.normalized() * moveSpeed * dt;
    }

    // Clamp to game bounds
    final s = gameRef.size;
    position.x = position.x.clamp(0 + size.x / 2, s.x - size.x / 2);
    position.y = position.y.clamp(0 + size.y / 2, s.y - size.y / 2);

    // Cooldown
    if (_cooldown > 0) _cooldown -= dt;
  }

  @override
  void render(Canvas canvas) {
    // Draw a simple ship triangle pointing up
    final paint = Paint()..color = Colors.cyanAccent;
    final path = Path()
      ..moveTo(0, -size.y / 2)
      ..lineTo(size.x / 2, size.y / 2)
      ..lineTo(-size.x / 2, size.y / 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Movement via arrows or WASD
    final left =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final right =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    final up =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    final down =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);

    _move
      ..setValues(0, 0)
      ..x += left ? -1 : 0
      ..x += right ? 1 : 0
      ..y += up ? -1 : 0
      ..y += down ? 1 : 0;

    // Fire on Space/Ctrl
    final fire =
        keysPressed.contains(LogicalKeyboardKey.space) ||
        keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        keysPressed.contains(LogicalKeyboardKey.controlRight);
    if (fire) {
      tryFire();
    }

    return true;
  }

  void tryFire() {
    if (_activeBullets >= maxSimultaneousBullets) return;
    if (_cooldown > 0) return;

    _cooldown = bulletCooldown;

    // Shoot toward screen center (enemy core placeholder)
    final target = gameRef.size / 2;
    final dir = (target - position);
    if (dir.length2 == 0) return;

    final bullet = PlayerBullet(
      velocity: dir,
      onDespawn: () {
        _activeBullets = math.max(0, _activeBullets - 1);
      },
    )..position = position.clone();

    _activeBullets += 1;
    gameRef.add(bullet);
  }
}
