import 'dart:async';
import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/enemy_sprite.dart';
import 'package:cyclone_game/components/enemy/enemy_core.dart';
import 'package:cyclone_game/components/enemy/enemy_blast.dart';
import 'package:cyclone_game/components/enemy/enemy_main_shot.dart';
import 'package:cyclone_game/components/effects/castle_destruction.dart';
import 'package:cyclone_game/components/effects/castle_ring_piece.dart';
import 'package:cyclone_game/components/effects/explosion.dart';
import 'package:cyclone_game/components/effects/electric_shield.dart';
import 'package:cyclone_game/components/effects/mine_chain_detonation.dart';
import 'package:cyclone_game/components/player/player.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/components/pickups/yummy_pickup.dart';
import 'package:cyclone_game/components/pickups/mine_challenge_yummy.dart';
import 'package:cyclone_game/components/hazards/mine.dart';
import 'package:cyclone_game/components/hazards/challenge_mine.dart';
import 'package:cyclone_game/game/mine_challenge/mine_challenge_controller.dart';
import 'package:cyclone_game/game/mine_challenge/mine_challenge_rules.dart';
import 'package:cyclone_game/game/pickup_spawn_rules.dart';
import 'package:cyclone_game/game/ui/victory_bonus_tally.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/game/world/starfield.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cyclone_game/game/audio_manager.dart';
import 'package:cyclone_game/utils.dart';

// Global keyboard handler component for macOS/Web that handles
// Q (exit to home) and P (pause/resume). Keeps keyboard logic out of the Game
// to avoid Flame's KeyboardEvents vs HasKeyboardHandlerComponents conflict.
class _GlobalKeyHandler extends Component
    with KeyboardHandler, HasGameRef<CycloneGame> {
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (!isMacOrWeb) return false;
    if (event is KeyDownEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.keyQ)) {
        gameRef.exitToHome();
        return true;
      }
      if (keysPressed.contains(LogicalKeyboardKey.keyP)) {
        if (gameRef.isPaused) {
          gameRef.resumeGame();
        } else {
          gameRef.pauseGame();
        }
        return true;
      }
    }
    return false;
  }
}

/// CycloneGame: root game per blueprint
class CycloneGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  // Runs a silent scripted intro using real game components
  bool isStartupDemo = false;
  bool isPlaying = false;
  VoidCallback? _onVolChanged;
  late final GameManager gm;
  late final Player player;
  late final Starfield starfield;
  EnemySprite? enemy;
  bool _levelTransitioning = false;
  bool get isLevelTransitioning => _levelTransitioning;
  bool _isRespawning = false;
  bool _mineChallengePending = false;
  bool _mineChallengeActive = false;
  bool _standaloneMineChallenge = false;
  bool get isMineChallengeActive => _mineChallengeActive;
  MineChallengeController? _mineChallengeController;
  TimerComponent? _respawnTimer;
  TextComponent? _gameOverBanner;
  TextComponent? _victoryBanner;
  VictoryBonusTally? _bonusTally;
  TimerComponent? _victoryTransitionTimer;
  bool _submittedThisRun = false;
  bool _inUpdateTree = false;

  @override
  void onRemove() {
    if (_onVolChanged != null) {
      gm.volume.removeListener(_onVolChanged!);
      _onVolChanged = null;
    }
    super.onRemove();
  }

  // Spawner timers
  double _pickupSpawnTimer = 0;
  double _mineSpawnTimer = 0;
  // Auto-fire timer for TripleAutoYummy to ensure hands-free firing
  double _tripleAutoFireTimer = 0;
  // Bonus countdown half-second accumulator
  double _bonusTickAccum = 0;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  Future<void> _ensurePlayerMounted() async {
    if (player.isRemoving) {
      if (_inUpdateTree) {
        await Future<void>.microtask(() {});
      }
    }
    if (player.isRemoving) {
      processLifecycleEvents();
    }
    if (!player.isMounted) {
      await add(player);
    }
  }

  void _processLifecycleEventsSafely() {
    if (_inUpdateTree) {
      scheduleMicrotask(processLifecycleEvents);
    } else {
      processLifecycleEvents();
    }
  }

  @override
  void update(double dt) {
    _inUpdateTree = true;
    try {
      super.update(dt);
    } finally {
      _inUpdateTree = false;
    }
    if (!isPlaying) return;
    if (_levelTransitioning) {
      if (!_mineChallengeActive) {
        _pickupSpawnTimer += dt;
        final pickupInterval = PickupSpawnRules.intervalForLevel(
          gm.currentLevel.value,
        );
        if (_pickupSpawnTimer >= pickupInterval) {
          _pickupSpawnTimer = 0;
          _maybeSpawnPickup();
        }
      }
      return;
    }

    // Tick timed Triple+Auto weapon override and auto-revert when finished
    gm.tickTripleAuto(
      dt,
      restorePlayer: () {
        // Restore previous player weapon flags
        player.hasContinuousFire = gm.prevHasContinuous;
        player.hasTripleSpread = gm.prevHasTriple;
      },
    );

    // The challenge owns its spawning and does not drain the regular level bonus.
    if (_mineChallengeActive) return;

    // Timed spawns for pickups and mines while playing
    _pickupSpawnTimer += dt;
    _mineSpawnTimer += dt;

    // Bonus countdown: every 0.5s, decrease by 5 until 0
    _bonusTickAccum += dt;
    if (_bonusTickAccum >= 0.5) {
      _bonusTickAccum -= 0.5;
      final cur = gm.levelBonus.value;
      if (cur > 0) {
        gm.levelBonus.value = (cur - 5).clamp(0, 5000);
      }
    }

    // Spawn yummy pickups more frequently as the player levels up
    final pickupInterval = PickupSpawnRules.intervalForLevel(
      gm.currentLevel.value,
    );
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

    // Fix asset path: all images are under lib/assets/.
    // Ensure Flame's image cache looks under lib/assets/ for Sprite.load('*.png').
    images.prefix = 'lib/assets/';

    gm = GameManager();
    // Load persisted settings/high scores but don't block UI heavily
    // ignore: unawaited_futures
    gm.loadPrefs();

    // Apply initial master volume and listen for changes
    AudioManager.instance.updateMasterVolume(gm.volume.value);
    _onVolChanged = () {
      AudioManager.instance.updateMasterVolume(gm.volume.value);
    };
    gm.volume.addListener(_onVolChanged!);

    // World setup (default viewport)
    starfield = Starfield(sizeProvider: () => size);

    // Entities centered
    final center = size / 2;

    // Player centered
    player = Player(gm: gm)
      ..position = center.clone()
      ..anchor = Anchor.center;

    // Layering: background starfield; gameplay entities are added when a new game starts
    await add(starfield);

    // Global keyboard handler for macOS/Web (Q exit, P pause/resume)
    await add(_GlobalKeyHandler());

    // Immediately run the silent startup demo, then show Home
    resumeEngine();
    // ignore: discarded_futures
    playStartupDemo();
  }

  void startGame() {
    _submittedThisRun = false;
    _clearMineChallenge();
    _standaloneMineChallenge = false;
    _cancelRespawnTimer();
    _bonusTally?.removeFromParent();
    _bonusTally = null;
    _victoryBanner?.removeFromParent();
    _victoryBanner = null;
    _victoryTransitionTimer?.removeFromParent();
    _victoryTransitionTimer = null;
    // If a startup demo or any intro overlays are still around, force-clean them
    isStartupDemo = false;
    // Remove any leftover fade or logo components to ensure a clean start
    children.whereType<_BlackFade>().forEach((c) => c.removeFromParent());
    children.whereType<_LogoSplash>().forEach((c) => c.removeFromParent());

    // Fresh game state
    gm.resetForNewGame();
    // Reset per-level bonus countdown
    gm.levelBonus.value = 5000;
    _bonusTickAccum = 0;
    _levelTransitioning = false;
    _isRespawning = false;
    isPlaying = true;

    // Reset internal timers for spawns and auto-fire helpers
    _pickupSpawnTimer = 0;
    _mineSpawnTimer = 0;
    _tripleAutoFireTimer = 0;

    // Ensure Game Over banner is cleared
    _gameOverBanner?.removeFromParent();
    _gameOverBanner = null;

    // Remove any lingering entities and projectiles from prior run
    _removeAllEnemies();
    _removeAllProjectiles();

    // Ensure player exists with pristine state and is mounted
    player.resetForNewGame();
    _ensurePlayerMounted();
    player.revive();
    player.position = _randomSafeSpawn();

    // Ensure an enemy is present and centered
    // (spawn will replace existing if needed)
    // ignore: discarded_futures
    _spawnEnemy();

    // Overlays: switch to in-game HUD/controls only
    overlays.remove('home');
    overlays.remove('instructions');
    overlays.add('hud');
    overlays.add('controls');

    // Audio: new game begin SFX and start background hum (looping quietly)
    AudioManager.instance.playBegin();
    // ignore: discarded_futures
    AudioManager.instance.playBackgroundHum(volume: 0.22);

    // Make sure engine is running
    resumeGame();
  }

  Future<void> startMineChallengeGame() async {
    _clearMineChallenge();
    _standaloneMineChallenge = true;
    _submittedThisRun = true;
    _cancelRespawnTimer();
    _bonusTally?.removeFromParent();
    _bonusTally = null;
    _victoryBanner?.removeFromParent();
    _victoryBanner = null;
    _victoryTransitionTimer?.removeFromParent();
    _victoryTransitionTimer = null;
    isStartupDemo = false;
    children.whereType<_BlackFade>().forEach((c) => c.removeFromParent());
    children.whereType<_LogoSplash>().forEach((c) => c.removeFromParent());

    gm.resetForNewGame();
    gm.levelBonus.value = 5000;
    _bonusTickAccum = 0;
    _levelTransitioning = true;
    _isRespawning = false;
    isPlaying = true;
    _pickupSpawnTimer = 0;
    _mineSpawnTimer = 0;
    _tripleAutoFireTimer = 0;

    _gameOverBanner?.removeFromParent();
    _gameOverBanner = null;
    _removeAllEnemies();
    _removeAllProjectiles();
    player.resetForNewGame();

    overlays.remove('home');
    overlays.remove('instructions');
    overlays.add('controls');

    AudioManager.instance.playBegin();
    // ignore: discarded_futures
    AudioManager.instance.playBackgroundHum(volume: 0.22);
    resumeGame();

    await _ensurePlayerMounted();
    player.revive();
    player.position = size / 2;
    player.stopMotion();
    _mineChallengePending = true;
    _startMineChallenge();
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
    if (isStartupDemo) return; // ignore victory during startup demo
    if (_levelTransitioning) return;
    _levelTransitioning = true;

    // Remove current enemy safely if present, with SFX and explosion
    if (enemy != null && enemy!.isMounted) {
      final e = enemy!;
      _detonateSparkMines(e.position);
      AudioManager.instance.playEnemyExplode();
      final maxRadius =
          e.shield?.redRadius ?? e.size.x * (isPhone ? 1 : 1.3) * 1.35 * 1.25;
      final destruction =
          CastleDestruction(
              rings: _snapshotCastleRings(e),
              shipSprite: e.sprite,
              shipSize: e.size,
              shipAngle: e.angle,
              maxRadius: maxRadius,
              onShipExploded: () {
                AudioManager.instance.playEnemyExplode();
                if (isPlaying) unawaited(_completeVictoryAndAdvance());
              },
            )
            ..position = e.position.clone()
            ..priority = 999;
      add(destruction);
      e.removeFromParent();
    }
    enemy = null;
  }

  Future<void> flareVictoryExplosionThenWin() async {
    if (isStartupDemo) return;
    if (_levelTransitioning) return;
    _levelTransitioning = true;

    // 1) Mines explode nearest to the castle first.
    final e = enemy;
    _detonateSparkMines(e?.position ?? size / 2);

    // 2) Enemy rings electric flash + ship explosion
    if (e != null && e.isMounted) {
      // Approximate shield radii as in EnemySprite
      final double rYellow = e.size.x * (isPhone ? 1 : 1.3);
      final double rOrange = rYellow * 1.35;
      final double rRed = rOrange * 1.25;
      for (final r in [rRed, rOrange, rYellow]) {
        final fx = ElectricShield(radius: r, arcCount: 5)
          ..position = e.position.clone()
          ..priority = 999;
        add(fx);
        add(
          TimerComponent(
            period: 0.5,
            removeOnFinish: true,
            onTick: () {
              fx.removeFromParent();
            },
          ),
        );
      }
      AudioManager.instance.playEnemyExplode();
      final destruction =
          CastleDestruction(
              rings: _snapshotCastleRings(e),
              shipSprite: e.sprite,
              shipSize: e.size,
              shipAngle: e.angle,
              maxRadius: rRed,
              onShipExploded: AudioManager.instance.playEnemyExplode,
            )
            ..position = e.position.clone()
            ..priority = 999;
      add(destruction);
      e.removeFromParent();
      enemy = null;
    }

    // 3) Small delay before banner
    add(
      TimerComponent(
        period: 3.0,
        removeOnFinish: true,
        onTick: () async {
          if (isPlaying) await _completeVictoryAndAdvance();
        },
      ),
    );
  }

  void _detonateSparkMines(Vector2 origin) {
    final mines = children.whereType<SparkMine>().toList()
      ..sort(
        (a, b) => a.position
            .distanceToSquared(origin)
            .compareTo(b.position.distanceToSquared(origin)),
      );
    if (mines.isEmpty) return;

    for (final mine in mines) {
      mine.prime();
    }

    add(
      MineChainDetonation(
        count: mines.length,
        interval: math.min(0.15, 1.5 / mines.length),
        onDetonate: (index) {
          final mine = mines[index];
          if (mine.isMounted && !mine.isRemoving) mine.detonate();
        },
      ),
    );
  }

  List<CastleRingSnapshot> _snapshotCastleRings(EnemySprite enemy) {
    final shield = enemy.shield;
    if (shield == null) return const [];

    return [shield.redRing, shield.orangeRing, shield.yellowRing]
        .map(
          (ring) => CastleRingSnapshot(
            outerRadius: ring.outerRadius,
            angleOffset: ring.angleOffset,
            angularVelocity: ring.angularVelocity,
            color: ring.color,
            glowColor: ring.glowColor,
            destroyedSegments: ring.destroyedSegments,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _completeVictoryAndAdvance() async {
    // Award base points for destroying enemy
    gm.addScore(100);
    // Award remaining time bonus
    final bonus = gm.levelBonus.value;
    gm.levelBonus.value = 0;

    // Show the victory banner and count the time bonus into the score.
    final center = size / 2;
    final banner = TextComponent(
      text: 'You Won!',
      anchor: Anchor.center,
      position: Vector2(center.x, center.y - 56),
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _victoryBanner = banner;

    final tally =
        VictoryBonusTally(
            total: bonus,
            duration: 2.5,
            startDelay: 0.35,
            score: gm.score.value,
            lives: gm.lives.value,
            onAddScore: (points) => gm.addScore(points),
            onComplete: _onVictoryTallyComplete,
          )
          ..position = Vector2(center.x, center.y + 2)
          ..priority = 1000;
    _bonusTally = tally;

    await add(banner);
    await add(tally);

    // Increment level
    gm.currentLevel.value = gm.currentLevel.value + 1;

    // Randomize starfield every 10 levels (10, 20, 30, ...)
    if (gm.currentLevel.value % 10 == 0) {
      try {
        starfield.randomize();
      } catch (_) {}
    }
  }

  void _onVictoryTallyComplete() {
    if (!isPlaying || _victoryTransitionTimer != null) return;
    final timer = TimerComponent(
      period: 1.5,
      removeOnFinish: true,
      onTick: () async {
        _victoryTransitionTimer = null;
        _victoryBanner?.removeFromParent();
        _victoryBanner = null;
        _bonusTally?.removeFromParent();
        _bonusTally = null;
        if (_mineChallengePending) {
          _startMineChallenge();
        } else {
          await _resumeNextRound();
        }
      },
    );
    _victoryTransitionTimer = timer;
    add(timer);
  }

  void queueMineChallenge() {
    if (!isPlaying || _mineChallengePending || _mineChallengeActive) return;
    _mineChallengePending = true;
  }

  void _startMineChallenge() {
    if (!isPlaying || !_mineChallengePending || _mineChallengeActive) return;
    _mineChallengePending = false;
    _mineChallengeActive = true;
    overlays.remove('hud');
    _pickupSpawnTimer = 0;
    _levelTransitioning = false;
    _cancelRespawnTimer();
    _removeAllProjectiles();

    _ensurePlayerMounted();
    player.revive();
    player.position = size / 2;
    player.stopMotion();

    final controller = MineChallengeController(
      onFinished: _onMineChallengeFinished,
    );
    _mineChallengeController = controller;
    add(controller);
  }

  void _onMineChallengeFinished(bool won) {
    if (!_mineChallengeActive || !isPlaying) return;
    _mineChallengeActive = false;
    _mineChallengeController?.removeFromParent();
    _mineChallengeController = null;
    _levelTransitioning = true;

    final center = size / 2;
    if (!won) {
      AudioManager.instance.playPlayerExplode();
      final boom = Explosion(maxRadius: 64, duration: 0.6)
        ..position = player.position.clone();
      add(boom);
      player.kill();
      if (player.isMounted) player.removeFromParent();
    }

    final banner = TextComponent(
      text: won ? 'Mine Challenge Won!' : 'Challenge Failed\nNo Bonus',
      anchor: Anchor.center,
      position: Vector2(center.x, center.y - 56),
      priority: 1000,
      textRenderer: TextPaint(
        style: TextStyle(
          color: won ? Colors.amber : Colors.orangeAccent,
          fontSize: won ? 38 : 36,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _victoryBanner = banner;
    add(banner);

    if (won) {
      final tally =
          VictoryBonusTally(
              total: MineChallengeRules.bonusPoints,
              duration: 2.5,
              startDelay: 0.35,
              score: gm.score.value,
              lives: gm.lives.value,
              onAddScore: (points) => gm.addScore(points),
              onComplete: _scheduleMineChallengeResume,
            )
            ..position = Vector2(center.x, center.y + 2)
            ..priority = 1000;
      _bonusTally = tally;
      add(tally);
    } else {
      _scheduleMineChallengeResume(delay: 2.0);
    }
  }

  void _scheduleMineChallengeResume({double delay = 1.5}) {
    if (!isPlaying || _victoryTransitionTimer != null) return;
    final timer = TimerComponent(
      period: delay,
      removeOnFinish: true,
      onTick: () async {
        _victoryTransitionTimer = null;
        if (_standaloneMineChallenge) {
          _victoryBanner?.removeFromParent();
          _victoryBanner = null;
          _bonusTally?.removeFromParent();
          _bonusTally = null;
          showHomeOverlayClean();
          return;
        }
        await _resumeNextRound();
      },
    );
    _victoryTransitionTimer = timer;
    add(timer);
  }

  Future<void> _resumeNextRound() async {
    _victoryBanner?.removeFromParent();
    _victoryBanner = null;
    _bonusTally?.removeFromParent();
    _bonusTally = null;
    _victoryTransitionTimer?.removeFromParent();
    _victoryTransitionTimer = null;

    final playerNeedsSpawn = !player.isMounted || player.isRemoving;
    await _ensurePlayerMounted();
    if (playerNeedsSpawn || !player.isAlive) {
      player.revive();
      player.position = _randomSafeSpawn();
    }
    await _spawnEnemy();
    overlays.add('hud');
    _pickupSpawnTimer = 0;
    gm.levelBonus.value = 5000;
    _bonusTickAccum = 0;
    _levelTransitioning = false;
  }

  void _cancelRespawnTimer() {
    _respawnTimer?.removeFromParent();
    _respawnTimer = null;
    _isRespawning = false;
  }

  void _clearMineChallenge() {
    _mineChallengeController?.removeFromParent();
    _mineChallengeController = null;
    children.whereType<MineChallengeMine>().forEach(
      (mine) => mine.removeFromParent(),
    );
    _mineChallengePending = false;
    _mineChallengeActive = false;
    _standaloneMineChallenge = false;
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

  bool isPaused = false;

  void pauseGame() {
    if (isPaused) return;
    isPaused = true;
    pauseEngine();
    // Fully stop background audio to ensure silence while paused
    // ignore: discarded_futures
    AudioManager.instance.stopBackgroundHum();
  }

  void resumeGame() {
    if (!isPaused) return;
    isPaused = false;
    resumeEngine();
    // ignore: discarded_futures
    AudioManager.instance.resumeBackgroundHum();
  }

  void exitToHome() {
    final wasPlaying = isPlaying;
    // Transfer any remaining bonus before saving the run's score.
    _bonusTally?.flush();
    showHomeOverlayClean();
    _bonusTally?.removeFromParent();
    _bonusTally = null;
    _victoryBanner?.removeFromParent();
    _victoryBanner = null;
    _victoryTransitionTimer?.removeFromParent();
    _victoryTransitionTimer = null;
    // Save high score only when the player explicitly exits mid-run
    if (wasPlaying && !_submittedThisRun) {
      _submittedThisRun = true;
      gm.submitHighScore(level: gm.currentLevel.value);
    }
  }

  /// Ensure Home overlay shows only the basic starfield and no audio.
  void showHomeOverlayClean() {
    _clearMineChallenge();
    _cancelRespawnTimer();
    isStartupDemo = false;
    isPlaying = false;
    _levelTransitioning = false;
    _isRespawning = false;
    // Remove gameplay entities and projectiles
    _removeAllEnemies();
    _removeAllProjectiles();
    if (player.isMounted) {
      player.removeFromParent();
    }
    _gameOverBanner = null;
    _victoryBanner = null;
    _victoryTransitionTimer = null;
    // Remove everything else (banners, effects, pickups, timers, intro
    // fade/logo) so only the starfield remains behind the Home menu.
    for (final c in children.toList()) {
      if (c is Starfield ||
          c is _GlobalKeyHandler ||
          c is World ||
          c is CameraComponent) {
        continue;
      }
      c.removeFromParent();
    }
    _processLifecycleEventsSafely();
    // Stop any background audio
    // ignore: discarded_futures
    AudioManager.instance.stopBackgroundHum();
    // Mark paused and pause engine so only overlays remain visually (starfield is static dots)
    isPaused = true;
    pauseEngine();
    // Render one clean frame (starfield only) so no stale gameplay visuals
    // remain frozen on screen behind the Home menu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isPaused && !isPlaying && overlays.isActive('home')) {
        stepEngine(stepTime: 0);
      }
    });
    // Overlays: leave only home
    overlays.remove('hud');
    overlays.remove('controls');
    overlays.remove('instructions');
    if (!overlays.isActive('home')) {
      overlays.add('home');
    }
  }

  void returnToHome() {
    exitToHome();
  }

  // Handle player being destroyed by enemy fire
  void onPlayerHit() {
    if (isStartupDemo) return; // no life loss during startup demo
    if (_mineChallengeActive) return;
    if (_isRespawning || _levelTransitioning) return;

    // SFX: player ship destroyed
    AudioManager.instance.playPlayerExplode();

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
      final timer = TimerComponent(
        period: 2.0,
        removeOnFinish: true,
        onTick: () {
          _respawnTimer = null;
          // Re-add player if needed and place safely
          _ensurePlayerMounted();
          player.revive();
          player.position = _randomSafeSpawn();
          _isRespawning = false;
        },
      );
      _respawnTimer = timer;
      add(timer);
    } else {
      // Game Over: remove enemy and show banner; starfield remains
      _showGameOver();
    }
  }

  void _showGameOver() {
    // Remove any enemy instances and hostile projectiles
    _removeAllEnemies();
    _removeAllProjectiles();

    // Audio: play game over sting after 1.5 seconds and stop background hum
    add(
      TimerComponent(
        period: 1.5,
        removeOnFinish: true,
        onTick: AudioManager.instance.playGameOver,
      ),
    );
    // ignore: discarded_futures
    AudioManager.instance.stopBackgroundHum();

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
          color: Colors.orange,
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
          // Submit final score/level/name to leaderboard (only once)
          if (!_submittedThisRun) {
            _submittedThisRun = true;
            gm.submitHighScore(level: gm.currentLevel.value);
          }
          // Navigate back to home
          exitToHome();
        },
      ),
    );
  }

  void resetGameState() {
    // Clear transitions
    _clearMineChallenge();
    _cancelRespawnTimer();
    _levelTransitioning = false;
    _isRespawning = false;
    isPlaying = false;

    // Clear banners
    _gameOverBanner?.removeFromParent();
    _gameOverBanner = null;

    // Reset game model (scores, lives, etc.)
    gm.resetForNewGame();

    // Remove gameplay entities
    _removeAllEnemies();
    _removeAllProjectiles();
    if (player.isMounted) {
      player.removeFromParent();
    }
    // Leave starfield running; player/enemy will be added when a new game actually starts
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
    children.whereType<MineChallengeMine>().forEach(
      (c) => c.removeFromParent(),
    );
    children.whereType<YummyPickup>().forEach((c) => c.removeFromParent());
  }

  // --- Spawners ------------------------------------------------------------
  void _maybeSpawnPickup() {
    if (_mineChallengeActive) return;

    // Do not spam: limit concurrent pickups to 2
    final current = children.whereType<YummyPickup>().length;
    if (current >= 2) return;

    final rnd = math.Random();
    final level = gm.currentLevel.value;

    // Build allowed pickup constructors based on level gating
    final List<YummyPickup Function()> allowed = [
      () => ShieldYummy(),
      () => PointsYummy(_randomPointValue(rnd)),
      () => LifeYummy(),
      () => TripleSpreadYummy(),
    ];
    // AutoYummy (ContinuousFire) after level > 19
    if (level > 19) {
      allowed.add(() => ContinuousFireYummy());
    }
    // LockYummy after level > 9
    if (level > 9) {
      allowed.add(() => LockYummy());
    }
    // TripleAutoYummy after level > 19
    if (level > 19) {
      allowed.add(() => TripleAutoYummy());
    }
    if (level > 9 && !_mineChallengePending && !_mineChallengeActive) {
      allowed.add(() => MineChallengeYummy());
    }
    // FlareYummy after level > 14, except during victory transitions.
    if (PickupSpawnRules.canSpawnFlare(
      level: level,
      levelTransitioning: _levelTransitioning,
    )) {
      allowed.add(() => FlareYummy());
    }

    if (allowed.isEmpty) return;
    final comp = allowed[rnd.nextInt(allowed.length)]();

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
    // Cap increases every 10 levels up to 5, then increases a bit faster after level 40
    final level = gm.currentLevel.value;
    final baseCap = math.min(1 + ((level - 1) ~/ 10), 5);
    int extra = 0;
    if (level > 40) {
      extra = ((level - 40) ~/ 5); // +1 every 5 levels after 40
    }
    final cap = math.min(baseCap + extra, 10); // soft cap at 10 mines
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

  Future<void> playStartupDemo() async {
    if (isStartupDemo) return;
    isStartupDemo = true;
    isPlaying = false; // ensure normal spawners won’t run

    // Clear any previous entities
    _removeAllEnemies();
    _removeAllProjectiles();
    if (player.isMounted) {
      player.removeFromParent();
    }

    // Spawn centered enemy
    await _spawnEnemy();

    // Place player at bottom-left and aim at center
    await _ensurePlayerMounted();
    player.revive();
    final Vector2 pPos = Vector2(size.x * 0.18, size.y * 0.82);
    player.position = pPos;
    final Vector2 center = size / 2;
    final Vector2 dirToCenter = (center - pPos).normalized();
    player.angle = math.atan2(dirToCenter.y, dirToCenter.x) + math.pi / 2;

    // Gentle drift toward center during the demo
    add(
      _DriftTween(
        target: player,
        from: pPos,
        to: pPos + dirToCenter * (size.length / 28),
        duration: 1.6,
      ),
    );

    // Fire 5 silent shots toward the center gap
    await AudioManager.instance.withSfxMuted(() async {
      for (int i = 0; i < 5; i++) {
        add(
          TimerComponent(
            period: 0.12 * i,
            removeOnFinish: true,
            onTick: () {
              player.fireSingleNoLimit();
            },
          ),
        );
      }
    });

    // One enemy blast toward player (silent)
    await AudioManager.instance.withSfxMuted(() async {
      add(
        TimerComponent(
          period: 0.8,
          removeOnFinish: true,
          onTick: () {
            final e = enemy;
            if (e == null) return;
            final safeAngle = e.safeBlastAngleToward(
              player.position,
              leadTime: 0,
            );
            if (safeAngle == null) return;
            e.fireBlastAlongAngle(safeAngle, playSound: false);
          },
        ),
      );
    });

    // After ~2.4s start fading gameplay to black, then show logo and home
    add(
      TimerComponent(
        period: 2.4,
        removeOnFinish: true,
        onTick: () {
          final fade = _BlackFade(
            duration: 0.6,
            onDone: () async {
              // Cleanup gameplay visuals
              _removeAllEnemies();
              if (player.isMounted) player.removeFromParent();
              await _showTitleThenHome();
            },
          );
          add(fade);
        },
      ),
    );
  }

  Future<void> _showTitleThenHome() async {
    // Fade in logo for 1.5s, then fade out and go to Home
    final logo = _LogoSplash(
      fadeIn: 0.5,
      hold: 1.5,
      fadeOut: 0.6,
      onFinished: () {
        showHomeOverlayClean();
      },
    );
    await add(logo);
  }
}

// --- Simple helper components for the startup demo --------------------------

class _DriftTween extends Component with HasGameRef<CycloneGame> {
  _DriftTween({
    required this.target,
    required this.from,
    required this.to,
    required this.duration,
  });
  final PositionComponent target;
  final Vector2 from;
  final Vector2 to;
  final double duration;
  double _t = 0;
  @override
  void update(double dt) {
    super.update(dt);
    if (!target.isMounted) return;
    _t += dt;
    final r = (_t / duration).clamp(0.0, 1.0);
    target.position = from + (to - from) * r;
    if (r >= 1.0) removeFromParent();
  }
}

class _BlackFade extends PositionComponent with HasGameRef<CycloneGame> {
  _BlackFade({required this.duration, this.onDone}) : super(priority: 10000);
  final double duration;
  final VoidCallback? onDone;
  double _t = 0;
  bool _doneCalled = false;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2.zero();
    size = gameRef.size.clone();
    anchor = Anchor.topLeft;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!_doneCalled && _t >= duration) {
      _t = duration;
      _doneCalled = true;
      onDone?.call();
      // Auto-remove the fade once complete to avoid blocking future gameplay
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_t / duration).clamp(0.0, 1.0);
    final paint = Paint()..color = Colors.black.withOpacity(alpha);
    canvas.drawRect(Offset.zero & Size(size.x, size.y), paint);
  }
}

class _LogoSplash extends PositionComponent with HasGameRef<CycloneGame> {
  _LogoSplash({
    required this.fadeIn,
    required this.hold,
    required this.fadeOut,
    this.onFinished,
  }) : super(priority: 11000);
  final double fadeIn;
  final double hold;
  final double fadeOut;
  final VoidCallback? onFinished;
  late Sprite _sprite;
  double _t = 0;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2.zero();
    size = gameRef.size.clone();
    anchor = Anchor.topLeft;
    _sprite = await Sprite.load('logo/cyclone_logo_title.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final total = fadeIn + hold + fadeOut;
    if (_t >= total) {
      onFinished?.call();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final total = fadeIn + hold + fadeOut;
    final t = _t.clamp(0.0, total);
    double alpha;
    if (t <= fadeIn) {
      alpha = (t / fadeIn);
    } else if (t <= fadeIn + hold) {
      alpha = 1.0;
    } else {
      final outT = (t - fadeIn - hold);
      alpha = 1.0 - (outT / fadeOut);
    }
    final paint = Paint()
      ..color = Colors.white.withOpacity(alpha.clamp(0.0, 1.0));

    // Center the logo sprite on screen
    final screen = Size(size.x, size.y);
    final targetW = screen.width * 0.62;
    final ratio = targetW / (_sprite.srcSize.x);
    final targetH = _sprite.srcSize.y * ratio;
    final dst = Rect.fromCenter(
      center: Offset(screen.width / 2, screen.height / 2),
      width: targetW,
      height: targetH,
    );
    _sprite.renderRect(canvas, dst, overridePaint: paint);
  }
}
