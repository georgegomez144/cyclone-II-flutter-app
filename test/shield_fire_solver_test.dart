import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/shield_fire_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const spawnDistance = 12.0;
  const speed = 500.0;
  const baseRadius = 9.0;
  const growthPerSecond = 1.5;
  const margin = 1.0;

  List<ShieldRingSnapshot> ringsWithGap({
    required double targetAngle,
    List<double>? angularVelocities,
    int gapCount = 3,
  }) {
    final radii = [60.0, 81.0, 101.0];
    return List.generate(radii.length, (ringIndex) {
      final destroyed = List<bool>.filled(ShieldFireSolver.sides, false);
      if (ringIndex < gapCount) {
        destroyed[ShieldFireSolver.segmentIndexAt(targetAngle, 0)] = true;
      }
      return ShieldRingSnapshot(
        outerRadius: radii[ringIndex],
        innerRadius: radii[ringIndex] - 0.5,
        angleOffset: 0,
        angularVelocity: angularVelocities?[ringIndex] ?? 0,
        destroyedSegments: destroyed,
      );
    });
  }

  double? solve(
    List<ShieldRingSnapshot> rings, {
    double targetAngle = 0,
    double maxDeviation = math.pi / 12,
    double leadTime = 0,
  }) => ShieldFireSolver.findSafeAngle(
    rings: rings,
    targetAngle: targetAngle,
    spawnDistance: spawnDistance,
    speed: speed,
    baseRadius: baseRadius,
    growthPerSecond: growthPerSecond,
    leadTime: leadTime,
    maxDeviation: maxDeviation,
    margin: margin,
  );

  group('ShieldFireSolver', () {
    test('returns null when all ring segments are intact', () {
      final rings = ringsWithGap(targetAngle: 0, gapCount: 0);

      expect(solve(rings), isNull);
    });

    test('finds a clear angle through aligned static gaps', () {
      final rings = ringsWithGap(targetAngle: 0);
      final angle = solve(rings);

      expect(angle, isNotNull);
      expect(
        ShieldFireSolver.pathIsClear(
          rings: rings,
          angle: angle!,
          spawnDistance: spawnDistance,
          speed: speed,
          baseRadius: baseRadius,
          growthPerSecond: growthPerSecond,
          leadTime: 0,
          margin: margin,
        ),
        isTrue,
      );
    });

    test('returns null when one ring has no opening', () {
      final rings = ringsWithGap(targetAngle: 0, gapCount: 2);

      expect(solve(rings), isNull);
    });

    test('moves off an open ray when the blast clips a gap vertex', () {
      const targetAngle = 0.001;
      final rings = ringsWithGap(targetAngle: targetAngle);
      final angle = solve(rings, targetAngle: targetAngle);

      expect(angle, isNotNull);
      expect(angle, greaterThan(targetAngle + math.pi / 720));
    });

    test('accounts for rotation before ring crossing', () {
      final rings = ringsWithGap(
        targetAngle: 0,
        angularVelocities: [0, 0, math.pi / 2],
      );

      expect(solve(rings), isNull);
    });

    test('segment indexing matches rendered segment angles', () {
      const offset = 0.37;
      const segmentSize = 2 * math.pi / ShieldFireSolver.sides;
      for (var index = 0; index < ShieldFireSolver.sides; index++) {
        final angle = offset - math.pi / 2 + (index + 0.5) * segmentSize;
        expect(ShieldFireSolver.segmentIndexAt(angle, offset), index);
      }
    });
  });
}
