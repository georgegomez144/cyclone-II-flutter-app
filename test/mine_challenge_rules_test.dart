import 'dart:math' as math;

import 'package:cyclone_game/game/mine_challenge/mine_challenge_rules.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MineChallengeRules', () {
    test('caps spawning at 20 mines', () {
      final rules = MineChallengeRules();

      for (var i = 0; i < MineChallengeRules.totalMines; i++) {
        expect(rules.registerSpawn(), isTrue);
      }

      expect(rules.spawned, MineChallengeRules.totalMines);
      expect(rules.registerSpawn(), isFalse);
      expect(rules.canSpawn, isFalse);
    });

    test('wins only after all 20 spawned mines are destroyed', () {
      final rules = MineChallengeRules();

      for (var i = 0; i < MineChallengeRules.totalMines; i++) {
        rules.registerSpawn();
        expect(rules.registerDestroyed(), isTrue);
        expect(rules.isWon, i == MineChallengeRules.totalMines - 1);
      }

      expect(rules.destroyed, MineChallengeRules.totalMines);
      expect(rules.isWon, isTrue);
      expect(rules.isOver, isTrue);
      expect(rules.registerDestroyed(), isFalse);
    });

    test('a hit ends the challenge without a win or more spawns', () {
      final rules = MineChallengeRules();
      rules.registerSpawn();
      rules.registerDestroyed();

      expect(rules.registerHit(), isTrue);
      expect(rules.isLost, isTrue);
      expect(rules.isWon, isFalse);
      expect(rules.canSpawn, isFalse);
      expect(rules.registerSpawn(), isFalse);
      expect(rules.registerDestroyed(), isFalse);
    });

    test('bonus is 2000 points', () {
      expect(MineChallengeRules.bonusPoints, 2000);
    });

    test('spawn points are outside the screen', () {
      final size = Vector2(800, 600);
      final random = math.Random(17);

      for (var i = 0; i < 100; i++) {
        final point = MineChallengeRules.offscreenSpawnPoint(size, random);
        expect(
          point.x < 0 || point.x > size.x || point.y < 0 || point.y > size.y,
          isTrue,
        );
      }
    });
  });
}
