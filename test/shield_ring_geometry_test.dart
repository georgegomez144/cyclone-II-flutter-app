import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/shield_ring_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShieldRingGeometry', () {
    const radius = 100.0;
    const segmentAngle = 2 * math.pi / 12;

    test('returns the outer radius at a vertex angle', () {
      final edgeRadius = ShieldRingGeometry.edgeRadiusAt(
        outerRadius: radius,
        angleOffset: 0,
        worldAngle: -math.pi / 2,
      );

      expect(edgeRadius, closeTo(radius, 1e-10));
    });

    test('returns the apothem at the middle of an edge', () {
      final edgeRadius = ShieldRingGeometry.edgeRadiusAt(
        outerRadius: radius,
        angleOffset: 0,
        worldAngle: -math.pi / 2 + segmentAngle / 2,
      );

      expect(edgeRadius, closeTo(radius * math.cos(math.pi / 12), 1e-10));
    });

    test('angle offset shifts the vertex angles', () {
      const angleOffset = 0.37;
      final edgeRadius = ShieldRingGeometry.edgeRadiusAt(
        outerRadius: radius,
        angleOffset: angleOffset,
        worldAngle: angleOffset - math.pi / 2,
      );

      expect(edgeRadius, closeTo(radius, 1e-10));
    });

    test('is periodic and symmetric around each edge normal', () {
      const angleOffset = 0.21;
      const angle = 0.83;
      final edgeRadius = ShieldRingGeometry.edgeRadiusAt(
        outerRadius: radius,
        angleOffset: angleOffset,
        worldAngle: angle,
      );
      final periodicRadius = ShieldRingGeometry.edgeRadiusAt(
        outerRadius: radius,
        angleOffset: angleOffset,
        worldAngle: angle + 2 * math.pi,
      );
      final edgeNormal = angleOffset - math.pi / 2 + segmentAngle / 2;
      final symmetricRadius = ShieldRingGeometry.edgeRadiusAt(
        outerRadius: radius,
        angleOffset: angleOffset,
        worldAngle: 2 * edgeNormal - angle,
      );

      expect(periodicRadius, closeTo(edgeRadius, 1e-10));
      expect(symmetricRadius, closeTo(edgeRadius, 1e-10));
    });
  });
}
