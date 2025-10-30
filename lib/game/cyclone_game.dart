import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/enemy_sprite.dart';
import 'package:cyclone_game/components/enemy/enemy_core.dart';
import 'package:cyclone_game/components/enemy/enemy_blast.dart';
import 'package:cyclone_game/components/enemy/enemy_main_shot.dart';
import 'package:cyclone_game/components/player/player.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/components/pickups/yummy_pickup.dart';
import 'package:cyclone_game/components/hazards/mine.dart';
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

  // Spawner timers
  double _pickupSpawnTimer = 0;
  double _mineSpawnTimer = 0;
  // Auto-fire timer for TripleAutoYummy to ensure hands-free firing
  double _tripleAutoFireTimer = 0;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  void update(double dt) {
    super.update(dt);
    if (_levelTransitioning) return;

    // Tick timed Triple+Auto weapon override and auto-revert when finished
    gm.tickTripleAuto(
      dt,
      restorePlayer: () {
        // Restore previous player weapon flags
        player.hasContinuousFire = gm.prevHasContinuous;
        player.hasTripleSpread = gm.prevHasTriple;
      },
    );

    // Timed spawns for pickups and mines while playing
    _pickupSpawnTimer += dt;
    _mineSpawnTimer += dt;

    // Spawn yummy pickups every 8–14 seconds randomly
    final pickupInterval = 10.0; // base
    if (_pickupSpawnTimer >= pickupInterval) {
      _pickupSpawnTimer = 0;
      _maybeSpawnPickup();
    }

    // Spawn mines every 3 seconds up to cap
    if (_mineSpawnTimer >= 3.0) {
      _mineSpawnTimer = 0;
      _maybeSpawnMine();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _pickupSpawnTimer = 0;
    _mineSpawnTimer = 0;

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
    player.revive();
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
    // Strong singleton guarantee: remove ALL enemy instances before spawning
    _removeAllEnemies();

    // Create and center a single enemy
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
    final center = size / 2;
    final banner = TextComponent(
      text: 'You Won!',
      anchor: Anchor.center,
      position: center,
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Show quick summary: total points and lives remaining
    final summary = TextComponent(
      text: 'Score: ${gm.score.value}   Lives: ${gm.lives.value}',
      anchor: Anchor.topCenter,
      position: Vector2(center.x, center.y + 36),
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    await add(banner);
    await add(summary);

    // Increment level
    gm.currentLevel.value = gm.currentLevel.value + 1;

    // Save progress to leaderboard on each level increase
    gm.submitHighScore(level: gm.currentLevel.value);

    // After a delay, remove banner and respawn enemy for next level.
    // Keep player at current position (no random respawn after a win).
    add(
      TimerComponent(
        period: 1.5,
        removeOnFinish: true,
        onTick: () async {
          banner.removeFromParent();
          summary.removeFromParent();
          await _spawnEnemy();
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
    // Reset gameplay so next start is fresh from level 1
    resetGameState();
    pauseEngine();
    overlays.remove('hud');
    overlays.remove('controls');
    overlays.remove('instructions');
    overlays.add('home');
  }

  void returnToHome() {
    exitToHome();
  }

  // Handle player being destroyed by enemy fire
  void onPlayerHit() {
    if (_isRespawning || _levelTransitioning) return;

    // Mark player dead and remove visual if still mounted
    player.kill();
    if (player.isMounted) {
      player.removeFromParent();
    }

    // Lose a life and decide next action
    gm.loseLife();

    if (gm.lives.value > 0) {
      // Schedule respawn after 2 seconds at a random location
      _isRespawning = true;
      add(
        TimerComponent(
          period: 2.0,
          removeOnFinish: true,
          onTick: () {
            // Re-add player if needed and place safely
            if (!player.isMounted) {
              add(player);
            }
            player.revive();
            player.position = _randomSafeSpawn();
            _isRespawning = false;
          },
        ),
      );
    } else {
      // Game Over: remove enemy and show banner; starfield remains
      _showGameOver();
    }
  }

  void _showGameOver() {
    // Remove any enemy instances and hostile projectiles
    _removeAllEnemies();
    _removeAllProjectiles();

    // Remove HUD/controls; keep engine running so starfield animates
    overlays.remove('hud');
    overlays.remove('controls');

    // Show Game Over banner if not already
    _gameOverBanner?.removeFromParent();
    _gameOverBanner = TextComponent(
      text: 'Game Over',
      anchor: Anchor.center,
      position: size / 2,
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_gameOverBanner!);

    // After 2 seconds, save to leaderboard and go to home screen
    add(
      TimerComponent(
        period: 2.0,
        removeOnFinish: true,
        onTick: () {
          // Submit final score/level/name to leaderboard
          gm.submitHighScore(level: gm.currentLevel.value);
          // Navigate back to home
          exitToHome();
        },
      ),
    );
  }

  void resetGameState() {
    // Clear transitions
    _levelTransitioning = false;
    _isRespawning = false;

    // Clear banners
    _gameOverBanner?.removeFromParent();
    _gameOverBanner = null;

    // Reset game model
    gm.resetForNewGame();

    // Ensure player is present and centered
    if (!player.isMounted) {
      add(player);
    }
    player
      ..angle = 0
      ..position = size / 2;

    // Remove enemies and projectiles
    _removeAllEnemies();
    _removeAllProjectiles();

    // Respawn a fresh enemy at center for next game
    // ignore: discarded_futures
    _spawnEnemy();
  }

  void _removeAllEnemies() {
    // Remove tracked enemy reference if mounted
    if (enemy != null && enemy!.isMounted) {
      enemy!.removeFromParent();
    }
    // Remove any stray EnemySprite or EnemyCore instances in the tree
    children.whereType<EnemySprite>().forEach((c) => c.removeFromParent());
    children.whereType<EnemyCore>().forEach((c) => c.removeFromParent());
    enemy = null;
  }

  void _removeAllProjectiles() {
    // Remove player bullets
    children.whereType<PlayerBullet>().forEach((c) => c.removeFromParent());
    // Remove enemy blasts and main shots
    children.whereType<EnemyBlast>().forEach((c) => c.removeFromParent());
    children.whereType<EnemyMainShot>().forEach((c) => c.removeFromParent());
    // Remove hazards and pickups
    children.whereType<SparkMine>().forEach((c) => c.removeFromParent());
    children.whereType<YummyPickup>().forEach((c) => c.removeFromParent());
  }

  // --- Spawners ------------------------------------------------------------
  void _maybeSpawnPickup() {
    // Do not spam: limit concurrent pickups to 2
    final current = children.whereType<YummyPickup>().length;
    if (current >= 2) return;

    // Randomly choose among pickups: Shield, Points, Life, ContinuousFire, TripleSpread, TripleAuto, Lock
    final rnd = math.Random();
    final int r = rnd.nextInt(7);
    YummyPickup comp;
    switch (r) {
      case 0:
        comp = ShieldYummy();
        break;
      case 1:
        comp = PointsYummy(_randomPointValue(rnd));
        break;
      case 2:
        comp = LifeYummy();
        break;
      case 3:
        comp = ContinuousFireYummy();
        break;
      case 4:
        comp = TripleSpreadYummy();
        break;
      case 5:
        comp = LockYummy();
        break;
      default:
        comp = TripleAutoYummy();
        break;
    }

    // Spawn away from player and enemy center
    final pos = _randomSpawnAwayFromPlayer(minDist: size.length / 6);
    comp.position = pos;
    add(comp);
  }

  int _randomPointValue(math.Random rnd) {
    const options = [1500, 3000, 4500, 9000];
    return options[rnd.nextInt(options.length)];
  }

  void _maybeSpawnMine() {
    // Cap increases every 10 levels up to 5
    final level = gm.currentLevel.value;
    final cap = math.min(1 + ((level - 1) ~/ 10), 5);
    final current = children.whereType<SparkMine>().length;
    if (current >= cap) return;

    // Must have an enemy to spawn from
    final e = enemy;
    if (e == null || !e.isMounted) return;

    // Spawn from the enemy ship's nose with a small forward offset
    final Vector2 forward = Vector2(0, -1)..rotate(e.angle);
    final double spawnDist = (e.size.y / 2) + 16.0;
    final Vector2 pos = e.position + forward * spawnDist;

    final mine = SparkMine(start: pos);
    add(mine);
  }

  Vector2 _randomSpawnAwayFromPlayer({double? minDist}) {
    final rnd = math.Random();
    final s = size;
    final avoid = player.position.clone();
    final double minD = minDist ?? math.min(s.x, s.y) * 0.25;
    for (int i = 0; i < 24; i++) {
      final x = rnd.nextDouble() * s.x;
      final y = rnd.nextDouble() * s.y;
      final p = Vector2(x, y);
      if (p.distanceTo(avoid) >= minD && p.distanceTo(s / 2) >= minD * 0.6) {
        return p;
      }
    }
    return Vector2(rnd.nextDouble() * s.x, rnd.nextDouble() * s.y);
  }

  Vector2 _randomEdgeSpawnAwayFromPlayer() {
    final rnd = math.Random();
    final s = size;
    // Pick one of four edges
    final edge = rnd.nextInt(4);
    double x, y;
    switch (edge) {
      case 0: // top
        x = rnd.nextDouble() * s.x;
        y = 0;
        break;
      case 1: // bottom
        x = rnd.nextDouble() * s.x;
        y = s.y;
        break;
      case 2: // left
        x = 0;
        y = rnd.nextDouble() * s.y;
        break;
      default: // right
        x = s.x;
        y = rnd.nextDouble() * s.y;
    }
    var p = Vector2(x, y);
    // Ensure not too close to player
    if (p.distanceTo(player.position) < math.min(s.x, s.y) * 0.25) {
      p = _randomSpawnAwayFromPlayer();
    }
    return p;
  }
}
