import 'package:cyclone_game/components/pickups/yummy_pickup.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MineChallengeYummy extends YummyPickup {
  MineChallengeYummy() : super(colorTint: Colors.purpleAccent);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final icon = Icons.bolt;
    add(
      TextComponent(
        text: String.fromCharCode(icon.codePoint),
        anchor: Anchor.center,
        position: size / 2,
        priority: 10,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  String floatingText() => 'Mine Challenge';

  @override
  void applyEffect(GameManager gm) {
    gameRef.queueMineChallenge();
  }
}
