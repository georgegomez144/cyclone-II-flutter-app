import 'dart:math' as math;

class ShieldRingGeometry {
  static double edgeRadiusAt({
    required double outerRadius,
    required double angleOffset,
    required double worldAngle,
    int sides = 12,
  }) {
    final segmentAngle = 2 * math.pi / sides;
    final relativeAngle = worldAngle - angleOffset + math.pi / 2;
    final normalizedAngle = relativeAngle % (2 * math.pi);
    final segmentIndex = (normalizedAngle / segmentAngle).floor();
    final angleFromEdgeNormal =
        normalizedAngle - (segmentIndex + 0.5) * segmentAngle;

    return outerRadius *
        math.cos(math.pi / sides) /
        math.cos(angleFromEdgeNormal);
  }
}
