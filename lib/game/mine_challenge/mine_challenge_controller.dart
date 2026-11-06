import 'dart:math' as math;

import 'package:cyclone_game/components/hazards/challenge_mine.dart';
import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/mine_challenge/mine_challenge_rules.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MineChallengeController extends PositionComponent
    with HasGameReference<CycloneGame> {
  MineChallengeController({required this.onFinished});

  final void Function(bool won) onFinished;
  final MineChallengeRules _rules = MineChallengeRules();
  final math.Random _random = math.Random();
  final Set<MineChallengeMine> _mines = {};
  late final TextComponent _counter;
  double _spawnTimer = 1.0;
  bool _finished = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2.zero();
    size = game.size.clone();

    final title = TextComponent(
      text: 'Mine Challenge!',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, 42),
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _counter = TextComponent(
      text: 'Mines: 0/${MineChallengeRules.totalMines}',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, 78),
      priority: 1000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    addAll([title, _counter]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished || !_rules.canSpawn) return;
    _spawnTimer -= dt;
    if (_spawnTimer > 0) return;

    if (_rules.registerSpawn()) {
      final mine = MineChallengeMine(
        start: MineChallengeRules.offscreenSpawnPoint(game.size, _random),
        onDestroyed: _onMineDestroyed,
        onHitPlayer: _onMineHitPlayer,
      );
      _mines.add(mine);
      game.add(mine);
      _spawnTimer = _rules.spawnInterval(_rules.spawned);
    }
  }

  void _onMineDestroyed() {
    if (!_rules.registerDestroyed()) return;
    _counter.text =
        'Mines: ${_rules.destroyed}/${MineChallengeRules.totalMines}';
    if (_rules.isWon) _finish(true);
  }

  void _onMineHitPlayer() {
    if (_rules.registerHit()) _finish(false);
  }

  void _finish(bool won) {
    if (_finished) return;
    _finished = true;
    for (final mine in _mines.toList()) {
      mine.removeFromParent();
    }
    _mines.clear();
    onFinished(won);
  }
}
