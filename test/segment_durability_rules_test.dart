import 'package:cyclone_game/components/enemy/segment_durability_rules.dart';
import 'package:cyclone_game/components/enemy/shield_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SegmentDurabilityRules', () {
    final cases = <int, int>{
      1: 2,
      99: 2,
      100: 3,
      149: 3,
      150: 4,
      199: 4,
      200: 5,
      500: 5,
    };

    for (final entry in cases.entries) {
      test('level ${entry.key} requires ${entry.value} hits', () {
        expect(SegmentDurabilityRules.hitsToDestroy(entry.key), entry.value);
      });
    }
  });

  test('a shield segment is destroyed on its configured hit', () async {
    final ring = ShieldRing(
      color: Colors.orange,
      glowColor: Colors.yellow,
      outerRadius: 100,
      innerRadius: 99.5,
      spinSpeed: 1,
      clockwise: true,
    )..hitsToDestroy = 3;
    await ring.onLoad();

    expect(ring.hitSegment(0), isFalse);
    expect(ring.isSegmentDestroyed(0), isFalse);
    expect(ring.hitSegment(0), isFalse);
    expect(ring.isSegmentDestroyed(0), isFalse);
    expect(ring.hitSegment(0), isTrue);
    expect(ring.isSegmentDestroyed(0), isTrue);

    ring.resetAll();

    expect(ring.hitsToDestroy, 3);
    expect(ring.hitSegment(0), isFalse);
    expect(ring.hitSegment(0), isFalse);
    expect(ring.hitSegment(0), isTrue);
  });
}
