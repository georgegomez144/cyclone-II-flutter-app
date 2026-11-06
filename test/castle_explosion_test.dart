import 'dart:math' as math;

import 'package:cyclone_game/components/effects/castle_explosion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CastleExplosion', () {
    test('emits sparks on its first update', () {
      final explosion = CastleExplosion(random: math.Random(1));

      explosion.update(0);

      expect(explosion.activeSparkCount, CastleExplosion.sparkCount);
    });

    test('sparks move outward from the castle center', () {
      final explosion = CastleExplosion(random: math.Random(1));
      explosion.update(0);
      final initialPositions = explosion.sparkPositions;

      explosion.update(0.1);

      for (var i = 0; i < initialPositions.length; i++) {
        expect(
          explosion.sparkPositions[i].distanceTo(initialPositions[i]),
          greaterThan(0),
        );
      }
    });

    test('sparks expire by the end of the effect duration', () {
      final explosion = CastleExplosion(duration: 1, random: math.Random(1));
      explosion.update(0);

      explosion.update(1);

      expect(explosion.activeSparkCount, 0);
    });

    test('rings start in staggered layers', () {
      final explosion = CastleExplosion(duration: 1, random: math.Random(1));
      explosion.update(0);

      expect(explosion.activeRingCount, 1);
      explosion.update(0.15);
      expect(explosion.activeRingCount, 1);
      explosion.update(0.1);
      expect(explosion.activeRingCount, 2);
    });

    test('finishes after the rings and sparks complete', () {
      final explosion = CastleExplosion(duration: 0.6, random: math.Random(1));
      explosion.update(0);
      explosion.update(0.59);

      expect(explosion.isFinished, isFalse);

      explosion.update(0.02);

      expect(explosion.isFinished, isTrue);
    });
  });
}
