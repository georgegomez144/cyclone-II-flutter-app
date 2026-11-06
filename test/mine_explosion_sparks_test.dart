import 'dart:math' as math;

import 'package:cyclone_game/components/effects/mine_explosion_sparks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MineExplosionSparks', () {
    test('emits the full burst immediately', () {
      final sparks = MineExplosionSparks(random: math.Random(1));

      expect(sparks.activeSparkCount, MineExplosionSparks.sparkCount);
      expect(sparks.isFinished, isFalse);
    });

    test('sparks move outward from the center in all directions', () {
      final sparks = MineExplosionSparks(random: math.Random(1));

      sparks.update(0.05);

      final positions = sparks.sparkPositions;
      expect(positions, hasLength(MineExplosionSparks.sparkCount));
      expect(positions.every((position) => position.length > 0), isTrue);
      expect(positions.any((position) => position.x < 0), isTrue);
      expect(positions.any((position) => position.x > 0), isTrue);
      expect(positions.any((position) => position.y < 0), isTrue);
      expect(positions.any((position) => position.y > 0), isTrue);
    });

    test('all sparks expire after their maximum lifetime', () {
      final sparks = MineExplosionSparks(random: math.Random(1));

      sparks.update(0.6);

      expect(sparks.activeSparkCount, 0);
      expect(sparks.isFinished, isTrue);
    });

    test('zero delta does not move or expire sparks', () {
      final sparks = MineExplosionSparks(random: math.Random(1));
      final before = sparks.sparkPositions;

      sparks.update(0);

      expect(sparks.activeSparkCount, MineExplosionSparks.sparkCount);
      expect(sparks.sparkPositions, before);
    });
  });
}
