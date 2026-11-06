import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/indestructible_segment_rules.dart';
import 'package:cyclone_game/components/enemy/shield_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndestructibleSegmentRules', () {
    test('does not mark segments indestructible before level 100', () {
      final segments = IndestructibleSegmentRules.roll(
        level: 99,
        ringCount: 3,
        sides: ShieldRing.sides,
        random: math.Random(1),
      );

      expect(segments, hasLength(3));
      expect(segments.every((ring) => ring.length == ShieldRing.sides), isTrue);
      expect(segments.expand((ring) => ring), everyElement(isFalse));
    });

    test('keeps the observed indestructible rate between 1% and 5%', () {
      const ringCount = 3;
      const rollCount = 1000;
      final random = math.Random(1);
      var indestructibleCount = 0;

      for (var roll = 0; roll < rollCount; roll++) {
        final segments = IndestructibleSegmentRules.roll(
          level: 100,
          ringCount: ringCount,
          sides: ShieldRing.sides,
          random: random,
        );

        expect(segments, hasLength(ringCount));
        expect(
          segments.every((ring) => ring.length == ShieldRing.sides),
          isTrue,
        );
        expect(segments.every((ring) => ring.any((value) => !value)), isTrue);
        indestructibleCount += segments
            .expand((ring) => ring)
            .where((indestructible) => indestructible)
            .length;
      }

      final observedRate =
          indestructibleCount / (rollCount * ringCount * ShieldRing.sides);
      expect(observedRate, inInclusiveRange(0.01, 0.05));
    });
  });

  test('an indestructible segment flashes without being destroyed', () {
    final ring = ShieldRing(
      color: Colors.orange,
      glowColor: Colors.yellow,
      outerRadius: 100,
      innerRadius: 99.5,
      spinSpeed: 1,
      clockwise: true,
    )..setIndestructible(List<bool>.generate(ShieldRing.sides, (i) => i == 0));

    expect(ring.hitSegment(0), isFalse);
    expect(ring.isSegmentIndestructible(0), isTrue);
    expect(ring.isSegmentDestroyed(0), isFalse);
  });
}
