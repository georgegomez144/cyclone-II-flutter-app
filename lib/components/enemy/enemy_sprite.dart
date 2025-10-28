import 'dart:math' as math;

import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/components.dart';

/// Simple enemy ship sprite pinned to the center of the screen.
/// Rotates every frame to face the player's current position.
class EnemySprite extends SpriteComponent with HasGameRef<CycloneGame> {
  EnemySprite() : super(size: Vector2.all(48), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('enemy_sprite.png');
    // Start centered
    position = gameRef.size / 2;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Keep enemy pinned in center on resize
    position = gameRef.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final player = gameRef.player;
    if (player.isMounted) {
      final toPlayer = (player.position - position);
      if (toPlayer.length2 > 0) {
        // Our sprite faces up by default; set angle to point toward player
        angle = math.atan2(toPlayer.y, toPlayer.x) + math.pi / 2;
      }
    }
  }
}
