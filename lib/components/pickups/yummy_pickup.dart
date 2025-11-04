import 'dart:math' as math;

import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:cyclone_game/game/audio_manager.dart';
import 'package:cyclone_game/components/hazards/mine.dart';
import 'package:cyclone_game/components/enemy/enemy_blast.dart';

/// Base pickup component rendered with the `assets/yummy_sprite.png` sprite.
/// Provides a small floating + flipping animation and handles collision
/// with the Player. Subclasses implement [applyEffect].
abstract class YummyPickup extends SpriteComponent
    with CollisionCallbacks, HasGameRef<CycloneGame> {
  YummyPickup({this.colorTint, this.points})
    : super(size: Vector2.all(54), anchor: Anchor.center);

  /// Optional color tint (visual differentiation for types).
  final Color? colorTint;

  /// For points pickup display purposes
  final int? points;

  // Animation state
  double _t = 0; // time accumulator for bobbing and flip

  // Gentle drift velocity across the screen
  Vector2 _vel = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('yummy_sprite.png');

    // Hitbox for overlap with player (active to detect player's passive)
    add(CircleHitbox.relative(0.6, parentSize: size));

    // Slight random initial rotation for variety
    angle = math.Random().nextDouble() * math.pi;

    // Gentle random drift direction and speed
    final rnd = math.Random();
    final theta = rnd.nextDouble() * math.pi * 2;
    final speed = 18 + rnd.nextDouble() * 18; // 18..36 px/sec
    _vel = Vector2(math.cos(theta), math.sin(theta)) * speed;

    // Optional tint via paint color filter
    if (colorTint != null) {
      paint.colorFilter = ColorFilter.mode(colorTint!, BlendMode.modulate);
    }

    // Auto-despawn after 20 seconds if not collected
    add(
      TimerComponent(
        period: 20.0,
        removeOnFinish: true,
        onTick: () {
          if (!isRemoving) {
            // SFX: yummy expired / discarded
            AudioManager.instance.playYummyDiscard();
            removeFromParent();
          }
        },
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;

    // Slow cross-screen drift
    position += _vel * dt;

    // Screen wrap-around so yummies keep floating
    final s = gameRef.size;
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    if (position.x < -halfW) position.x = s.x + halfW;
    if (position.x > s.x + halfW) position.x = -halfW;
    if (position.y < -halfH) position.y = s.y + halfH;
    if (position.y > s.y + halfH) position.y = -halfH;

    // Bobbing up/down and pulsating scale
    final bob = math.sin(_t * 2.4) * 2.0; // +/-2 px
    position.y += bob * dt; // subtle vertical drift overlay

    // Slow spin so all yummies rotate
    const spinSpeed = 1.5; // radians per second
    angle += spinSpeed * dt;

    // Fake Y-axis flip by scaling X between -1 and 1
    final flip = math.sin(_t * 6.0);
    scale = Vector2(
      0.7 + 0.3 * flip.abs(),
      0.7 + 0.15 * math.cos(_t * 3.0).abs(),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other == gameRef.player) {
      // SFX: pickup collected
      AudioManager.instance.playYummyPickup();
      applyEffect(gameRef.gm);
      // Small floating text feedback
      _spawnFloatingText();
      removeFromParent();
    } else {
      // In frustrating mode, enemy blasts and mines can destroy yummies
      final diff = gameRef.gm.difficulty.value;
      if (diff == Difficulty.frustrating &&
          (other is EnemyBlast || other is SparkMine)) {
        // SFX: yummy destroyed
        AudioManager.instance.playYummyDiscard();
        removeFromParent();
      }
    }
  }

  void _spawnFloatingText() {
    final text = floatingText();
    final comp = TextComponent(
      text: text,
      anchor: Anchor.center,
      position: position.clone(),
      priority: 2000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amber,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
    gameRef.add(comp);
    gameRef.add(
      TimerComponent(
        period: 0.9,
        removeOnFinish: true,
        onTick: () {
          comp.removeFromParent();
        },
      ),
    );
  }

  /// Floating text shown when this pickup is collected.
  String floatingText() => points != null ? '+$points' : 'Shield Full';

  /// Apply this pickup's gameplay effect.
  void applyEffect(GameManager gm);
}

class ShieldYummy extends YummyPickup {
  ShieldYummy() : super(colorTint: Colors.yellowAccent.withOpacity(0.9));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Shield icon
    final iconChar = String.fromCharCode(Icons.shield.codePoint);
    add(
      TextComponent(
        text: iconChar,
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y / 2),
        priority: 10,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: Icons.shield.fontFamily,
            package: Icons.shield.fontPackage,
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  String floatingText() => 'Shield +1';

  @override
  void applyEffect(GameManager gm) {
    // Grants a single-hit shield that blocks one enemy blast.
    gameRef.player.setOneHitShield(true);
  }
}

class PointsYummy extends YummyPickup {
  PointsYummy(int pts) : super(points: pts, colorTint: Colors.white);

  @override
  void applyEffect(GameManager gm) {
    gm.addScore(points ?? 0);
  }
}

class LifeYummy extends YummyPickup {
  LifeYummy() : super(colorTint: Colors.greenAccent);

  @override
  void applyEffect(GameManager gm) {
    gm.gainLife(amount: 1, maxLives: 9);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    // Do NOT call super here, to avoid the default text and double-callback.
    if (other == gameRef.player) {
      // Apply life gain with cap
      applyEffect(gameRef.gm);
      // Custom floating text
      final comp = TextComponent(
        text: '+1 Ship',
        anchor: Anchor.center,
        position: position.clone(),
        priority: 2000,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.lightGreenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
      gameRef.add(comp);
      gameRef.add(
        TimerComponent(
          period: 0.9,
          removeOnFinish: true,
          onTick: () {
            comp.removeFromParent();
          },
        ),
      );
      // Remove pickup
      removeFromParent();
    }
  }
}

/// Grants continuous fire while holding the fire button.
class ContinuousFireYummy extends YummyPickup {
  ContinuousFireYummy() : super(colorTint: Colors.redAccent.withOpacity(0.9));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Add Material icon glyph centered
    final iconChar = String.fromCharCode(Icons.more_vert.codePoint);
    add(
      TextComponent(
        text: iconChar,
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y / 2),
        priority: 10,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: Icons.more_vert.fontFamily,
            package: Icons.more_vert.fontPackage,
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  String floatingText() => 'Auto Fire';

  @override
  void applyEffect(GameManager gm) {
    // Switching to Auto Fire disables Triple Spread (mutually exclusive)
    gameRef.player.hasContinuousFire = true;
    gameRef.player.hasTripleSpread = false;
    gm.currentBulletMode.value = BulletMode.auto;
  }
}

/// Grants triple spread bullets.
class TripleSpreadYummy extends YummyPickup {
  TripleSpreadYummy()
    : super(colorTint: Colors.lightBlueAccent.withOpacity(0.9));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Add Material icon glyph centered
    final iconChar = String.fromCharCode(Icons.workspaces.codePoint);
    add(
      TextComponent(
        text: iconChar,
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y / 2),
        priority: 10,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: Icons.workspaces.fontFamily,
            package: Icons.workspaces.fontPackage,
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  String floatingText() => 'Triple Shot';

  @override
  void applyEffect(GameManager gm) {
    // Switching to Triple Spread disables Auto Fire (mutually exclusive)
    gameRef.player.hasTripleSpread = true;
    gameRef.player.hasContinuousFire = false;
    gm.currentBulletMode.value = BulletMode.triple;
  }
}

/// Grants triple bullets + continuous auto-fire for 60 seconds, then reverts.
class TripleAutoYummy extends YummyPickup {
  TripleAutoYummy() : super(colorTint: Colors.cyanAccent.withOpacity(0.9));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      TextComponent(
        text: '3x ∞',
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y / 2),
        priority: 10,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  String floatingText() => '3x Auto 60s';

  @override
  void applyEffect(GameManager gm) {
    final player = gameRef.player;
    // Save previous flags to restore later
    gm.prevHasContinuous = player.hasContinuousFire;
    gm.prevHasTriple = player.hasTripleSpread;
    gm.prevBulletMode = gm.currentBulletMode.value;

    gm.startTripleAuto(
      durationSeconds: 60,
      applyToPlayer: () {
        player.hasTripleSpread = true;
        player.hasContinuousFire = true; // ensure continuous
        gm.currentBulletMode.value = BulletMode.triple;
      },
      restorePlayer: () {
        player.hasContinuousFire = gm.prevHasContinuous;
        player.hasTripleSpread = gm.prevHasTriple;
      },
    );
  }
}

class LockYummy extends YummyPickup {
  LockYummy() : super(colorTint: Colors.grey.withOpacity(0.85));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final iconChar = String.fromCharCode(Icons.lock.codePoint);
    add(
      TextComponent(
        text: iconChar,
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y / 2),
        priority: 10,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: Icons.lock.fontFamily,
            package: Icons.lock.fontPackage,
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  String floatingText() => 'Lock On';

  @override
  void applyEffect(GameManager gm) {
    gm.keepYummiesOnDeath.value = true;
  }
}

/// Flare Yummy: instant nova that destroys the current enemy, all mines,
/// and clears the shield rings. Only spawns after level 15.
class FlareYummy extends YummyPickup {
  FlareYummy() : super(colorTint: Colors.deepOrangeAccent.withOpacity(0.95));

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Centered Material icon glyph for flare
    final iconChar = String.fromCharCode(Icons.flare.codePoint);
    add(
      TextComponent(
        text: iconChar,
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y / 2),
        priority: 10,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: Icons.flare.fontFamily,
            package: Icons.flare.fontPackage,
            fontSize: 30,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.orangeAccent,
                blurRadius: 8,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  String floatingText() => 'Super Nova';

  @override
  void applyEffect(GameManager gm) {
    // Trigger a cinematic explosion sequence (mines, rings, enemy) then win
    gameRef.flareVictoryExplosionThenWin();
  }
}
