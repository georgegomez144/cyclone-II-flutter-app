import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/enemy_sprite.dart';
import 'package:cyclone_game/components/enemy/enemy_blast.dart';
import 'package:cyclone_game/components/enemy/enemy_main_shot.dart';
import 'package:cyclone_game/components/player/player.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/game/world/starfield.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

/// CycloneGame: root game per blueprint
class CycloneGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  late final GameManager gm;
  late final Player player;
  late final Starfield starfield;
  EnemySprite? enemy;
  bool _levelTransitioning = false;
  bool _isRespawning = false;
  TextComponent? _gameOverBanner;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Fix asset path: our images are under assets/ (not assets/images/).
    // Ensure Flame's image cache looks under assets/ for Sprite.load('*.png').
    images.prefix = 'assets/';

    gm = GameManager();
    // Load persisted settings/high scores but don't block UI heavily
    // ignore: unawaited_futures
    gm.loadPrefs();

    // World setup (default viewport)
    starfield = Starfield(sizeProvider: () => size);

    // Entities centered
    final center = size / 2;

    // Player centered
    player = Player(gm: gm)
      ..position = center.clone()
      ..anchor = Anchor.center;

    // Layering: background starfield, enemy, then player
    await add(starfield);
    await _spawnEnemy();
    await add(player);
  }

  void startGame() {
    // Fresh game state
    gm.resetForNewGame();
    _levelTransitioning = false;
    _isRespawning = false;

    // Ensure Game Over banner is cleared
    _gameOverBanner?.removeFromParent();
    _gameOverBanner = null;

    // Ensure player is mounted and placed at a safe spawn
    if (!player.isMounted) {
      add(player);
    }
    player.position = _randomSafeSpawn();

    // Ensure an enemy is present and centered
    // (spawn will replace existing if needed)
    // ignore: discarded_futures
    _spawnEnemy();

    overlays.remove('home');
    overlays.remove('instructions');
    overlays.add('hud');
    overlays.add('controls');
    resumeGame();
  }

  Future<void> _spawnEnemy() async {
    // Remove existing enemy if still mounted
    if (enemy != null && enemy!.isMounted) {
      enemy!.removeFromParent();
    }
    // Create and center enemy
    final e = EnemySprite()
      ..position = size / 2
      ..anchor = Anchor.center;
    enemy = e;
    await add(e);
  }

  Future<void> onEnemyDefeated() async {
    if (_levelTransitioning) return;
    _levelTransitioning = true;

    // Award points for destroying enemy
    gm.addScore(100);

    // Remove current enemy safely if present
    if (enemy != null && enemy!.isMounted) {
      enemy!.removeFromParent();
    }
    enemy = null;

    // Show centered 'You Won!' banner briefly
    final banner = TextComponent(
      text: 'You Won!',
      anchor: Anchor.center,
      position: size / 2,
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(banner);

    // Increment level
    gm.currentLevel.value = gm.currentLevel.value + 1;

    // After a delay, remove banner, respawn enemy and reposition player safely
    add(
      TimerComponent(
        period: 1.2,
        removeOnFinish: true,
        onTick: () async {
          banner.removeFromParent();
          await _spawnEnemy();
          // Move player to a safe spawn for next level
          player.position = _randomSafeSpawn();
          _levelTransitioning = false;
        },
      ),
    );
  }

  // Returns a random spawn position for the player that is not close to the enemy
  // (enemy is pinned at screen center). Also keeps a small margin from screen edges.
  Vector2 _randomSafeSpawn({int maxAttempts = 24}) {
    final rnd = math.Random();
    final s = size;
    // Safety margin from edges
    const double margin = 40.0;
    // Minimum safe distance from enemy at center
    final double minDistFromEnemy =
        math.min(s.x, s.y) * 0.30; // 30% of the smallest axis
    final center = s / 2;

    // Try a number of random samples
    for (int i = 0; i < maxAttempts; i++) {
      final x = margin + rnd.nextDouble() * (s.x - 2 * margin);
      final y = margin + rnd.nextDouble() * (s.y - 2 * margin);
      final candidate = Vector2(x, y);
      if (candidate.distanceTo(center) >= minDistFromEnemy) {
        return candidate;
      }
    }

    // Fallback: choose among corners the farthest from the center
    final corners = <Vector2>[
      Vector2(margin, margin),
      Vector2(s.x - margin, margin),
      Vector2(margin, s.y - margin),
      Vector2(s.x - margin, s.y - margin),
    ];
    corners.sort(
      (a, b) => b.distanceTo(center).compareTo(a.distanceTo(center)),
    );
    return corners.first;
  }

  void pauseGame() {
    pauseEngine();
  }

  void resumeGame() {
    resumeEngine();
  }

  void exitToHome() {
    pauseEngine();
    overlays.remove('hud');
    overlays.remove('controls');
    overlays.add('home');
  }

  void returnToHome() {
    exitToHome();
  }
}
