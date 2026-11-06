import 'package:cyclone_game/components/enemy/shield_fire_solver.dart';
import 'package:cyclone_game/components/player/player_bullet_sweep.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const segmentCount = ShieldFireSolver.sides;
  final pathSegment = ShieldFireSolver.segmentIndexAt(0, 0);

  List<ShieldRingSnapshot> makeRings({
    List<int> openRedSegments = const [],
    List<int> openOrangeSegments = const [],
    List<int> openYellowSegments = const [],
  }) {
    final openSegments = [
      openRedSegments,
      openOrangeSegments,
      openYellowSegments,
    ];
    const radii = [100.0, 80.0, 60.0];
    return List.generate(radii.length, (ringIndex) {
      final destroyed = List<bool>.filled(segmentCount, false);
      for (final segment in openSegments[ringIndex]) {
        destroyed[segment] = true;
      }
      return ShieldRingSnapshot(
        outerRadius: radii[ringIndex],
        innerRadius: radii[ringIndex] - 0.5,
        angleOffset: 0,
        angularVelocity: 0,
        destroyedSegments: destroyed,
      );
    });
  }

  PlayerBulletSweepHit? sweep({
    required Vector2 from,
    required Vector2 to,
    required List<ShieldRingSnapshot> rings,
    double bulletRadius = 0.25,
  }) => PlayerBulletSweep.firstHit(
    from: from,
    to: to,
    center: Vector2.zero(),
    rings: rings,
    bulletRadius: bulletRadius,
    coreRadius: 10,
  );

  group('PlayerBulletSweep', () {
    test('catches a fast bullet crossing a half-pixel outer ring', () {
      final hit = sweep(
        from: Vector2(106.5, 0),
        to: Vector2(93.5, 0),
        rings: makeRings(),
      );

      expect(hit?.isCore, isFalse);
      expect(hit?.ringIndex, 0);
      expect(hit?.segmentIndex, pathSegment);
    });

    test('passes a destroyed red segment and hits the orange ring', () {
      final hit = sweep(
        from: Vector2(110, 0),
        to: Vector2(70, 0),
        rings: makeRings(openRedSegments: [pathSegment]),
      );

      expect(hit?.isCore, isFalse);
      expect(hit?.ringIndex, 1);
      expect(hit?.segmentIndex, pathSegment);
    });

    test('reaches the core through destroyed segments on every ring', () {
      final allSegments = List<int>.generate(segmentCount, (index) => index);
      final hit = sweep(
        from: Vector2(120, 0),
        to: Vector2.zero(),
        rings: makeRings(
          openRedSegments: allSegments,
          openOrangeSegments: allSegments,
          openYellowSegments: allSegments,
        ),
      );

      expect(hit?.isCore, isTrue);
    });

    test('still reaches the core when the shield has no loaded rings', () {
      final hit = sweep(
        from: Vector2(30, 0),
        to: Vector2.zero(),
        rings: const [],
      );

      expect(hit?.isCore, isTrue);
    });

    test('returns no hit when the path misses rings and core', () {
      final hit = sweep(
        from: Vector2(120, 150),
        to: Vector2(-120, 150),
        rings: makeRings(),
      );

      expect(hit, isNull);
    });

    test('catches a bullet starting inside the rings and moving outward', () {
      final hit = sweep(
        from: Vector2(50, 0),
        to: Vector2(110, 0),
        rings: makeRings(),
      );

      expect(hit?.isCore, isFalse);
      expect(hit?.ringIndex, 2);
      expect(hit?.segmentIndex, pathSegment);
    });
  });
}
