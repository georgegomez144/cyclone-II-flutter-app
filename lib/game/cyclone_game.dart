import 'package:cyclone_game/components/player/player.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/game/world/starfield.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// CycloneGame: root game per blueprint
class CycloneGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  late final GameManager gm;
  late final Player player;
  late final Starfield starfield;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gm = GameManager();
    // Load persisted settings/high scores but don't block UI heavily
    // ignore: unawaited_futures
    gm.loadPrefs();

    // World setup (default viewport)
    starfield = Starfield(sizeProvider: () => size);

    // Player centered
    player = Player(gm: gm)
      ..position = size / 2
      ..anchor = Anchor.center;

    await addAll([starfield, player]);
  }

  void startGame() {
    gm.resetForNewGame();
    overlays.remove('home');
    overlays.remove('instructions');
    overlays.add('hud');
    overlays.add('controls');
    // Additional game start logic can go here
  }

  void returnToHome() {
    overlays.remove('hud');
    overlays.remove('controls');
    overlays.add('home');
  }
}
