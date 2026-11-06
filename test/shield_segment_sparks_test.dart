import 'dart:math' as math;

import 'package:cyclone_game/components/effects/shield_segment_sparks.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShieldSegmentSparks', () {
    final start = Vector2(10, -3);
    final end = Vector2(10, 3);

    test('emits a fixed burst immediately along the segment', () {
      final sparks = ShieldSegmentSparks(
        start: start,
        end: end,
        glowColor: Colors.orange,
        random: math.Random(1),
      );

      expect(sparks.activeSparkCount, ShieldSegmentSparks.sparkCount);
      for (final position in sparks.sparkPositions) {
        expect(position.x, closeTo(10, 1e-5));
        expect(position.y, inInclusiveRange(-3, 3));
      }
    });

    test('sparks move outward from the segment', () {
      final sparks = ShieldSegmentSparks(
        start: start,
        end: end,
        glowColor: Colors.orange,
        random: math.Random(1),
      );
      final initialPositions = sparks.sparkPositions;

      sparks.update(0.05);

      for (var i = 0; i < initialPositions.length; i++) {
        expect(
          sparks.sparkPositions[i].length,
          greaterThan(initialPositions[i].length),
        );
      }
    });

    test('all sparks expire and finish the effect', () {
      final sparks = ShieldSegmentSparks(
        start: start,
        end: end,
        glowColor: Colors.orange,
        random: math.Random(1),
      );

      sparks.update(1);

      expect(sparks.activeSparkCount, 0);
      expect(sparks.isFinished, isTrue);
    });

    test('zero delta does not move or expire sparks', () {
      final sparks = ShieldSegmentSparks(
        start: start,
        end: end,
        glowColor: Colors.orange,
        random: math.Random(1),
      );
      final before = sparks.sparkPositions;

      sparks.update(0);

      expect(sparks.activeSparkCount, ShieldSegmentSparks.sparkCount);
      expect(sparks.sparkPositions, before);
    });
  });
}
