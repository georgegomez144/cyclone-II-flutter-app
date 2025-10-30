import 'dart:math' as math;

import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/utils.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

class Player extends PositionComponent
    with KeyboardHandler, CollisionCallbacks, HasGameRef<CycloneGame> {
  Player({required this.gm})
    : super(
        size: Vector2(isPhone ? 44 : 52, isPhone ? 44 : 52),
        anchor: Anchor.center,
      );

  final GameManager gm;

  // Lifecycle
  bool isAlive = true;
  // Power-ups
  bool hasContinuousFire = false; // hold to auto-fire
  bool hasTripleSpread = false; // fire 3-way spread

  // Input hold states
  bool _uiFireHeld = false;
  bool _kbFireHeld = false;

  void kill() {
    isAlive = false;
    // Lose transient power-ups upon death
    hasContinuousFire = false;
    hasTripleSpread = false;
    _uiFireHeld = false;
    _kbFireHeld = false;
    // Reset HUD bullet mode
    gm.currentBulletMode.value = BulletMode.single;
  }

  void revive() {
    // Reset transient state on revive
    isAlive = true;
    _cooldown = 0;
    _activeBullets = 0;
    // Fire not held on revive
    _uiFireHeld = false;
    _kbFireHeld = false;
    // Ensure HUD bullet mode is reset
    gm.currentBulletMode.value = BulletMode.single;
  }

  // Movement (space-physics)
  final double maxSpeed = 520; // px/sec cap
  final double acceleration = 900; // px/sec^2 when input held
  final double damping = 0.98; // per-second damping when no input
  Vector2 _velocity = Vector2.zero();
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
  int maxSimultaneousBullets = 6;
  int _activeBullets = 0;
  double _cooldown = 0;
  final double bulletCooldown = 0.15; // seconds

  // Expose limited interaction for collisions
  void handleShieldImpact(Vector2 outwardNormal) {
    // If moving toward the ring head-on (velocity aligns with outward normal), reverse direction
    if (_velocity.length2 > 1e-3) {
      final vNorm = _velocity.normalized();
      final double cos = vNorm.dot(outwardNormal);
      // Threshold for "head-on"; > ~0.7 means within ~45 degrees of normal
      if (cos > 0.7) {
        // Reverse velocity to "turn around"
        _velocity = -_velocity;
      }
    }
  }

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
      position: size / 2,
    );
    add(_spriteComp);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Space-physics movement: apply acceleration when input present, otherwise damping.
    final input = _move;
    if (input.length2 > 0) {
      final dir = input.normalized();
      _velocity += dir * (acceleration * dt);
    } else {
      // Exponential damping toward zero
      final double damp = math.pow(damping, dt).toDouble();
      _velocity *= damp;
      // Snap to zero if extremely small to avoid drift
      if (_velocity.length2 < 1e-2) _velocity.setZero();
    }

    // Cap speed
    final speed = _velocity.length;
    if (speed > maxSpeed) {
      _velocity = _velocity.normalized() * maxSpeed;
    }

    // Integrate position
    position += _velocity * dt;

    // Rotate ship to face current movement (velocity) if significant; otherwise face input for responsiveness
    if (_velocity.length2 > 1e-2) {
      final v = _velocity;
      angle = math.atan2(v.y, v.x) + math.pi / 2;
    } else if (input.length2 > 0) {
      final dir = input.normalized();
      angle = math.atan2(dir.y, dir.x) + math.pi / 2;
    }

    // Continuous fire works only while the fire control is held AND the upgrade is active,
    // and only in single-shot mode (not with Triple Spread).
    final bool holdingFire = _uiFireHeld || _kbFireHeld;
    if (hasContinuousFire && !hasTripleSpread && holdingFire) {
      tryFire();
    }

    // Update moving visual state based on speed
    final isNowMoving = _velocity.length2 > 1.0;
    if (isNowMoving != _isMoving) {
      _isMoving = isNowMoving;
      if (_isMoving) {
        if (_spriteMoving != null) {
          _spriteComp.sprite = _spriteMoving;
          _spriteComp.size = size.clone() * 1.2;
        }
      } else {
        if (_spriteStationary != null) {
          _spriteComp.sprite = _spriteStationary;
          _spriteComp.size = size.clone() * 1;
        }
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

  // UI fire-hold setter (called from overlay)
  void setUiFireHeld(bool held) {
    _uiFireHeld = held;
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

    // Track hold state for continuous-fire powerup
    _kbFireHeld = fire;

    // Keyboard firing rules:
    // - If ContinuousFire is not active and TripleSpread is NOT active, allow hold to attempt firing (cooldown throttles via update())
    // - If TripleSpread is active, only fire on key DOWN (no hold-based continuous)
    if (fire && !hasContinuousFire && !hasTripleSpread) {
      tryFire();
    } else if (fire && hasTripleSpread && event is KeyDownEvent) {
      tryFire();
    }

    return true;
  }

  // Fire a single shot forward from the tip
  void tryFire() {
    if (!isAlive) return;

    // Throttle using shared cooldown and capacity
    if (_activeBullets >= maxSimultaneousBullets) return;
    if (_cooldown > 0) return;

    _cooldown = bulletCooldown; // 150 ms between shots for all modes

    // Forward direction based on current angle (ship points up in local space)
    final baseDir = Vector2(0, -1)..rotate(angle);

    if (hasTripleSpread) {
      // Fire 3 bullets with slight spread angles, respecting capacity
      final double spreadRad = 12 * math.pi / 200;
      final dirs = <Vector2>[
        baseDir.clone()..rotate(-spreadRad),
        baseDir.clone(),
        baseDir.clone()..rotate(spreadRad),
      ];
      for (final d in dirs) {
        if (_activeBullets >= maxSimultaneousBullets) break;
        _spawnBullet(d, offsetAlongNose: 0);
      }
    } else {
      // Single shot
      _spawnBullet(baseDir, offsetAlongNose: 0);
    }
  }

  void _spawnBulletNoLimit(Vector2 dir, {double offsetAlongNose = 0}) {
    final spawnPos =
        position + (dir.normalized() * (size.y / 2 + 4 + offsetAlongNose));
    final bullet = PlayerBullet(velocity: dir, onDespawn: () {})
      ..position = spawnPos;

    // Do not track active bullet counts or cooldowns for no-limit shots
    gameRef.add(bullet);
  }

  // Fire up to 3 inline bullets from the tip
  void tryFireBurst() {
    if (!isAlive) return;
    if (_cooldown > 0) return;
    if (_activeBullets >= maxSimultaneousBullets) return;

    _cooldown = bulletCooldown * 0;

    final dir = Vector2(0, -1)..rotate(angle);
    // spawn 3 bullets with small offsets along direction if capacity allows
    for (int i = 0; i < 3; i++) {
      if (_activeBullets >= maxSimultaneousBullets) break;
      _spawnBullet(dir, offsetAlongNose: i + 0);
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

  // Fire exactly one bullet immediately, ignoring cooldown and bullet caps.
  void fireSingleNoLimit() {
    if (!isAlive) return;
    final dir = Vector2(0, -1)..rotate(angle);
    _spawnBullet(dir, offsetAlongNose: -15);
  }
}
