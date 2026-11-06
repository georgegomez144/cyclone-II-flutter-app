import 'dart:math' as math;

import 'package:cyclone_game/components/effects/mine_sparks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MineSparks', () {
    test('emits sparks over time', () {
      final sparks = MineSparks(radius: 7, random: math.Random(1));

      sparks.update(0.04);

      expect(sparks.activeSparkCount, greaterThan(0));
    });

    test('sparks move away from the mine center', () {
      final sparks = MineSparks(radius: 7, random: math.Random(1));
      sparks.update(0.04);
      final initialPosition = sparks.sparkPositions.single;

      sparks.update(0.04);

      expect(
        sparks.sparkPositions.first.distanceTo(initialPosition),
        greaterThan(0),
      );
      expect(sparks.sparkPositions.first.length, greaterThan(7));
    });

    test('sparks travel radially within a tight reach', () {
      const radius = 7.0;
      final sparks = MineSparks(radius: radius, random: math.Random(1));
      sparks.update(0.04);
      final initialPosition = sparks.sparkPositions.single;

      sparks.update(0.1);

      final position = sparks.sparkPositions.first;
      final crossProduct =
          initialPosition.x * position.y - initialPosition.y * position.x;
      expect(crossProduct.abs(), lessThan(1e-5));
      expect(position.length, greaterThan(radius));
      expect(position.length, lessThanOrEqualTo(radius * 1.9));
    });

    test('old sparks expire as new sparks continue to emit', () {
      final sparks = MineSparks(radius: 7, random: math.Random(1));
      sparks.update(0.04);

      sparks.update(0.5);

      expect(sparks.activeSparkCount, greaterThan(0));
      for (final position in sparks.sparkPositions) {
        expect(position.length, closeTo(7, 1e-5));
      }
    });

    test('spark count stays within its cap', () {
      final sparks = MineSparks(radius: 7, random: math.Random(1));

      sparks.update(0.5);

      expect(sparks.activeSparkCount, MineSparks.maxSparkCount);
    });

    test('zero delta does not emit or move sparks', () {
      final sparks = MineSparks(radius: 7, random: math.Random(1));
      sparks.update(0.04);
      final before = sparks.sparkPositions.single;

      sparks.update(0);

      expect(sparks.activeSparkCount, 1);
      expect(sparks.sparkPositions.single, before);
    });
  });
}
