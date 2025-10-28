import 'dart:math' as math;

import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

class Player extends PositionComponent
    with KeyboardHandler, CollisionCallbacks, HasGameRef<CycloneGame> {
  Player({required this.gm})
    : super(size: Vector2(26, 26), anchor: Anchor.center);

  final GameManager gm;

  // Movement
  final double moveSpeed = 280; // px/sec
  Vector2 _keyMove = Vector2.zero();
  Vector2 _joyMove = Vector2.zero();
  bool _isMoving = false;

  // Visuals
  late final SpriteComponent _spriteComp;
  Sprite? _spriteStationary;
  Sprite? _spriteMoving;

  Vector2 get _move {
    final v = _keyMove + _joyMove;
    if (v.length2 > 1) return v.normalized();
    return v;
  }

  // Shooting
  int maxSimultaneousBullets = 3;
  int _activeBullets = 0;
  double _cooldown = 0;
  final double bulletCooldown = 0.15; // seconds

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Hitbox
    add(
      CircleHitbox.relative(0.6, parentSize: size)
        ..collisionType = CollisionType.passive,
    );

    // Load sprites and attach sprite component
    _spriteStationary = await Sprite.load('ship_sprite_stationary.png');
    _spriteMoving = await Sprite.load('ship_sprite_moving.png');
    _spriteComp = SpriteComponent(
      sprite: _spriteStationary,
      size: size.clone(),
      anchor: Anchor.center,
    );
    add(_spriteComp);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move
    if (_move.length2 > 0) {
      final dir = _move.normalized();
      position += dir * moveSpeed * dt;
      // Rotate ship to face movement direction (ship points up in local space)
      angle = math.atan2(dir.y, dir.x) + math.pi / 2;
      if (!_isMoving) {
        _isMoving = true;
        if (_spriteMoving != null) _spriteComp.sprite = _spriteMoving;
      }
    } else {
      if (_isMoving) {
        _isMoving = false;
        if (_spriteStationary != null) _spriteComp.sprite = _spriteStationary;
      }
    }

    // Screen wrap-around
    final s = gameRef.size;
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    if (position.x < -halfW) position.x = s.x + halfW;
    if (position.x > s.x + halfW) position.x = -halfW;
    if (position.y < -halfH) position.y = s.y + halfH;
    if (position.y > s.y + halfH) position.y = -halfH;

    // Cooldown
    if (_cooldown > 0) _cooldown -= dt;
  }

  // Joystick input (normalized -1..1 per axis)
  void setMoveFromJoystick(Vector2 vec) {
    _joyMove = vec.clone();
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
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

    _keyMove
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

  // Fire a single shot forward from the tip
  void tryFire() {
    if (_activeBullets >= maxSimultaneousBullets) return;
    if (_cooldown > 0) return;

    _cooldown = bulletCooldown;

    // Forward direction based on current angle (ship points up in local space)
    final dir = Vector2(0, -1)..rotate(angle);
    _spawnBullet(dir, offsetAlongNose: 0);
  }

  // Fire up to 3 inline bullets from the tip
  void tryFireBurst() {
    if (_cooldown > 0) return;
    if (_activeBullets >= maxSimultaneousBullets) return;

    _cooldown = bulletCooldown * 1.2;

    final dir = Vector2(0, -1)..rotate(angle);
    // spawn 3 bullets with small offsets along direction if capacity allows
    for (int i = 0; i < 3; i++) {
      if (_activeBullets >= maxSimultaneousBullets) break;
      _spawnBullet(dir, offsetAlongNose: i * 10.0);
    }
  }

  void _spawnBullet(Vector2 dir, {double offsetAlongNose = 0}) {
    final spawnPos =
        position + (dir.normalized() * (size.y / 2 + 4 + offsetAlongNose));
    final bullet = PlayerBullet(
      velocity: dir,
      onDespawn: () {
        _activeBullets = math.max(0, _activeBullets - 1);
      },
    )..position = spawnPos;

    _activeBullets += 1;
    gameRef.add(bullet);
  }
}
