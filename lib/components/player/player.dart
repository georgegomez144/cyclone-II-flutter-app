import 'dart:math' as math;

import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/utils.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:cyclone_game/game/audio_manager.dart';

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
  bool oneHitShieldActive = false; // absorbs a single enemy blast

  // Input hold states
  bool _uiFireHeld = false;
  bool _kbFireHeld = false;

  void kill() {
    isAlive = false;
    // Lose transient power-ups upon death unless Lock Yummy is active
    final keep = gm.keepYummiesOnDeath.value;
    if (!keep) {
      hasContinuousFire = false;
      hasTripleSpread = false;
      oneHitShieldActive = false;
      _refreshShieldGlow();
      // Reset HUD bullet mode
      gm.currentBulletMode.value = BulletMode.single;
    }
    _uiFireHeld = false;
    _kbFireHeld = false;
  }

  void revive() {
    // Reset transient state on revive
    isAlive = true;
    _cooldown = 0;
    _activeBullets = 0;
    // Fire not held on revive
    _uiFireHeld = false;
    _kbFireHeld = false;

    // If timed TripleAuto is still active, ensure triple+auto are applied
    if (gm.tripleAutoActive) {
      hasTripleSpread = true;
      hasContinuousFire = true;
      gm.currentBulletMode.value = BulletMode.triple;
    } else {
      // Otherwise, only reset HUD to Single if we are not keeping yummies
      if (!gm.keepYummiesOnDeath.value) {
        gm.currentBulletMode.value = BulletMode.single;
      }
    }

    // Re-apply shield glow based on flag
    _refreshShieldGlow();
  }

  // Movement (space-physics)
  final double maxSpeed = isPhone ? 460 : 520; // px/sec cap
  final double acceleration = 1200; // px/sec^2 when input held
  final double damping = 0.98; // per-second damping when no input
  Vector2 _velocity = Vector2.zero();
  Vector2 _keyMove = Vector2.zero();
  Vector2 _joyMove = Vector2.zero();
  bool _isMoving = false;

  // Visuals
  late final SpriteComponent _spriteComp;
  Sprite? _spriteStationary;
  Sprite? _spriteMoving;
  CircleComponent? _shieldGlow;

  void _refreshShieldGlow() {
    if (_shieldGlow == null) return;
    if (oneHitShieldActive) {
      if (_shieldGlow!.parent == null) {
        add(_shieldGlow!);
      }
    } else {
      _shieldGlow!.removeFromParent();
    }
  }

  void setOneHitShield(bool active) {
    oneHitShieldActive = active;
    _refreshShieldGlow();
  }

  void consumeOneHitShield() {
    if (!oneHitShieldActive) return;
    oneHitShieldActive = false;
    _refreshShieldGlow();
  }

  Vector2 get _move {
    final v = _keyMove + _joyMove;
    if (v.length2 > 1) return v.normalized();
    return v;
  }

  // Shooting
  int maxSimultaneousBullets = 3;
  int _activeBullets = 0;
  double _cooldown = 0;
  final double bulletCooldown = 0.1; // seconds

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

    // Shield glow visual (managed via _refreshShieldGlow)
    _shieldGlow =
        CircleComponent(
            radius: size.x * 0.7,
            anchor: Anchor.center,
            paint: ui.Paint()
              ..color = const ui.Color(0x5880D8FF)
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.outer, 16),
          )
          ..position = size / 2
          ..priority = -1;
    // Not added by default; shown when oneHitShieldActive

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

    // Continuous fire works only while the fire control is held AND the upgrade is active.
    // Allows continuous fire for both single and triple modes when enabled.
    final bool holdingFire = _uiFireHeld || _kbFireHeld;
    if (hasContinuousFire && holdingFire) {
      tryFire();
    }

    // Update moving visual state based on INPUT (not velocity):
    // When joystick/keys are released, show stationary sprite even if ship coasts.
    final bool inputPresent = input.length2 > 0;
    if (inputPresent != _isMoving) {
      _isMoving = inputPresent;
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
    if (!hasContinuousFire) {
      if (_activeBullets >= maxSimultaneousBullets) return;
    } else {
      if (_activeBullets >= 30) return;
    }
    if (_cooldown > 0) return;

    _cooldown = bulletCooldown; // 100 ms between shots for all modes

    // SFX for firing (once per trigger press)
    AudioManager.instance.playPlayerShot();

    // Forward direction based on current angle (ship points up in local space)
    final baseDir = Vector2(0, -1)..rotate(angle);

    if (hasTripleSpread) {
      // Fire 3 bullets with slight spread angles, respecting capacity
      final double spreadRad = 12 * math.pi / 300;
      final dirs = <Vector2>[
        baseDir.clone()..rotate(-spreadRad),
        baseDir.clone(),
        baseDir.clone()..rotate(spreadRad),
      ];
      for (final d in dirs) {
        if (_activeBullets >= 6) break;
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
    if (_activeBullets >= 3) return;

    _cooldown = bulletCooldown * 0;

    final dir = Vector2(0, -1)..rotate(angle);
    // spawn 3 bullets with small offsets along direction if capacity allows
    for (int i = 0; i < 3; i++) {
      if (_activeBullets >= 3) break;
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
