import 'package:cyclone_game/components/effects/explosion.dart';
import 'package:cyclone_game/components/effects/mine_explosion_sparks.dart';
import 'package:cyclone_game/components/effects/mine_sparks.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/game/audio_manager.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

class MineChallengeMine extends SpriteComponent
    with CollisionCallbacks, HasGameReference<CycloneGame> {
  MineChallengeMine({
    required Vector2 start,
    required this.onDestroyed,
    required this.onHitPlayer,
  }) : super(size: Vector2.all(20), anchor: Anchor.center) {
    position = start.clone();
  }

  final void Function() onDestroyed;
  final void Function() onHitPlayer;
  final Vector2 _velocity = Vector2.zero();
  bool _resolved = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load('spark_mine_sprite.png');
    add(MineSparks(radius: size.x / 2)..position = size / 2);
    add(
      CircleHitbox.relative(0.9, parentSize: size)
        ..collisionType = CollisionType.active,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0 || _resolved) return;

    final player = game.player;
    if (!player.isMounted) return;

    final direction = player.position - position;
    if (direction.length2 > 0) {
      _velocity.add(direction.normalized() * 110 * dt);
      final speed = _velocity.length;
      if (speed > 175) _velocity.scale(175 / speed);
      position += _velocity * dt;
    }
    angle += kMineSpinSpeed * dt;

    if (position.distanceTo(player.position) < 23) _hitPlayer();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerBullet && !other.consumed && !other.isRemoving) {
      other.consumed = true;
      other.removeFromParent();
      _destroy();
    }
  }

  void _destroy() {
    if (_resolved) return;
    _resolved = true;
    AudioManager.instance.playMineExplode();
    game.add(
      Explosion(maxRadius: 28, duration: 0.35)..position = position.clone(),
    );
    game.add(MineExplosionSparks()..position = position.clone());
    removeFromParent();
    onDestroyed();
  }

  void _hitPlayer() {
    if (_resolved) return;
    _resolved = true;
    AudioManager.instance.playMineExplode();
    game.add(
      Explosion(maxRadius: 34, duration: 0.4)..position = position.clone(),
    );
    game.add(MineExplosionSparks()..position = position.clone());
    removeFromParent();
    onHitPlayer();
  }
}
