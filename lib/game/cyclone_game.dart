import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/components/player/player.dart';

/// CycloneGame: root game per blueprint
class CycloneGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  late final GameManager gm;
  late final Player player;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gm = GameManager();

    // World setup (default viewport)

    // Player centered
    player = Player(gm: gm)
      ..position = size / 2
      ..anchor = Anchor.center;

    await addAll([player]);

    // Show HUD overlay once game is ready
    overlays.add('hud');
  }
}
