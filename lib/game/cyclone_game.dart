import 'package:cyclone_game/components/enemy/enemy_sprite.dart';
import 'package:cyclone_game/components/player/player.dart';
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
  late final EnemySprite enemy;

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

    // Enemy sprite centered
    enemy = EnemySprite()..position = center.clone();

    // Layering: background starfield, enemy, then player
    await addAll([starfield, enemy, player]);
  }

  void startGame() {
    gm.resetForNewGame();
    overlays.remove('home');
    overlays.remove('instructions');
    overlays.add('hud');
    overlays.add('controls');
    resumeGame();
    // Additional game start logic can go here
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
