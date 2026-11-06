import 'dart:math' as math;

import 'package:cyclone_game/game/pickup_spawn_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PickupSpawnRules', () {
    test('does not spawn FlareYummy during a level transition', () {
      expect(
        PickupSpawnRules.canSpawnFlare(level: 15, levelTransitioning: true),
        isFalse,
      );
    });

    test('spawns FlareYummy after level 14 outside a transition', () {
      expect(
        PickupSpawnRules.canSpawnFlare(level: 15, levelTransitioning: false),
        isTrue,
      );
    });

    test('does not spawn FlareYummy at or below level 14', () {
      expect(
        PickupSpawnRules.canSpawnFlare(level: 14, levelTransitioning: false),
        isFalse,
      );
    });

    test('spawns pickups 10% more frequently from level 1', () {
      expect(PickupSpawnRules.intervalForLevel(1), closeTo(10.0 / 1.10, 0.001));
    });

    test('keeps the initial frequency through level 10', () {
      expect(
        PickupSpawnRules.intervalForLevel(10),
        closeTo(10.0 / 1.10, 0.001),
      );
    });

    test('increases frequency by 2% at level 11', () {
      expect(
        PickupSpawnRules.intervalForLevel(11),
        closeTo(10.0 / 1.12, 0.001),
      );
    });

    test('increases frequency by another 2% at level 21', () {
      expect(
        PickupSpawnRules.intervalForLevel(21),
        closeTo(10.0 / 1.14, 0.001),
      );
    });

    test('treats levels below 1 as level 1', () {
      expect(PickupSpawnRules.intervalForLevel(0), closeTo(10.0 / 1.10, 0.001));
    });

    test('hazards destroy yummies starting at level 150', () {
      expect(PickupSpawnRules.hazardsDestroyYummies(149), isFalse);
      expect(PickupSpawnRules.hazardsDestroyYummies(150), isTrue);
    });

    test('keeps spawn intervals unchanged through level 149', () {
      final random = math.Random(1);
      expect(
        PickupSpawnRules.nextInterval(149, random),
        PickupSpawnRules.intervalForLevel(149),
      );
    });

    test('randomizes faster spawn intervals from level 150', () {
      const sampleCount = 1000;
      final baseInterval = PickupSpawnRules.intervalForLevel(150);
      final random = math.Random(1);
      var intervalSum = 0.0;

      for (var i = 0; i < sampleCount; i++) {
        final interval = PickupSpawnRules.nextInterval(150, random);
        expect(interval, greaterThanOrEqualTo(baseInterval * 0.25));
        expect(interval, lessThanOrEqualTo(baseInterval * 0.75));
        intervalSum += interval;
      }

      expect(intervalSum / sampleCount, lessThan(baseInterval));
    });

    test('increases concurrent pickup cap starting at level 150', () {
      expect(PickupSpawnRules.maxConcurrent(149), 2);
      expect(PickupSpawnRules.maxConcurrent(150), 4);
    });
  });
}
