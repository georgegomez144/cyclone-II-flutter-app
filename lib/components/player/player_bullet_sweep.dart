import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/shield_fire_solver.dart';
import 'package:cyclone_game/components/enemy/shield_ring_geometry.dart';
import 'package:flame/components.dart';

class PlayerBulletSweepHit {
  const PlayerBulletSweepHit.ring({
    required this.ringIndex,
    required this.segmentIndex,
  }) : isCore = false;

  const PlayerBulletSweepHit.core()
    : ringIndex = null,
      segmentIndex = null,
      isCore = true;

  final int? ringIndex;
  final int? segmentIndex;
  final bool isCore;
}

class PlayerBulletSweep {
  static const double _maxStep = 1;

  static PlayerBulletSweepHit? firstHit({
    required Vector2 from,
    required Vector2 to,
    required Vector2 center,
    required List<ShieldRingSnapshot> rings,
    required double bulletRadius,
    required double coreRadius,
  }) {
    final delta = to - from;
    final sampleCount = math.max(1, (delta.length / _maxStep).ceil());
    final previousDifferences = List<double?>.filled(rings.length, null);

    for (var sample = 0; sample <= sampleCount; sample++) {
      final progress = sample / sampleCount;
      final point = from + delta * progress;
      final relative = point - center;
      final distance = relative.length;
      final angle = math.atan2(relative.y, relative.x);

      for (var ringIndex = 0; ringIndex < rings.length; ringIndex++) {
        final ring = rings[ringIndex];
        final edgeRadius = ShieldRingGeometry.edgeRadiusAt(
          outerRadius: ring.outerRadius,
          angleOffset: ring.angleOffset,
          worldAngle: angle,
          sides: ring.destroyedSegments.length,
        );
        final edgeDifference = distance - edgeRadius;
        final innerEdge = edgeRadius - (ring.outerRadius - ring.innerRadius);
        final segmentIndex = ShieldFireSolver.segmentIndexAt(
          angle,
          ring.angleOffset,
          segmentCount: ring.destroyedSegments.length,
        );
        final segmentIntact =
            segmentIndex < ring.destroyedSegments.length &&
            !ring.destroyedSegments[segmentIndex];
        final inRingBand =
            distance >= innerEdge - bulletRadius &&
            distance <= edgeRadius + bulletRadius;
        final previousDifference = previousDifferences[ringIndex];
        final crossedEdge =
            previousDifference != null &&
            previousDifference * edgeDifference <= 0;

        if (segmentIntact && (inRingBand || crossedEdge)) {
          return PlayerBulletSweepHit.ring(
            ringIndex: ringIndex,
            segmentIndex: segmentIndex,
          );
        }
        previousDifferences[ringIndex] = edgeDifference;
      }

      if (distance <= coreRadius + bulletRadius) {
        return const PlayerBulletSweepHit.core();
      }
    }

    return null;
  }
}
