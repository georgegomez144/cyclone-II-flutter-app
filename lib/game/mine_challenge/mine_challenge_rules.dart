import 'dart:math' as math;

import 'package:flame/components.dart';

class MineChallengeRules {
  static const int totalMines = 20;
  static const int bonusPoints = 2000;

  int spawned = 0;
  int destroyed = 0;
  bool _hit = false;

  bool get canSpawn => !isOver && spawned < totalMines;
  bool get isWon => !_hit && destroyed == totalMines;
  bool get isLost => _hit;
  bool get isOver => isWon || isLost;

  bool registerSpawn() {
    if (!canSpawn) return false;
    spawned++;
    return true;
  }

  bool registerDestroyed() {
    if (isOver || destroyed >= spawned) return false;
    destroyed++;
    return true;
  }

  bool registerHit() {
    if (isOver) return false;
    _hit = true;
    return true;
  }

  double spawnInterval(int index) =>
      (1.35 - index * 0.025).clamp(0.85, 1.35).toDouble();

  static Vector2 offscreenSpawnPoint(
    Vector2 size,
    math.Random random, {
    double margin = 32,
  }) {
    final edge = random.nextInt(4);
    return switch (edge) {
      0 => Vector2(random.nextDouble() * size.x, -margin),
      1 => Vector2(random.nextDouble() * size.x, size.y + margin),
      2 => Vector2(-margin, random.nextDouble() * size.y),
      _ => Vector2(size.x + margin, random.nextDouble() * size.y),
    };
  }
}
