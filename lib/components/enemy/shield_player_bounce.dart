import 'dart:math' as math;

import 'package:flame/components.dart';

class ShieldPlayerCollision {
  const ShieldPlayerCollision({
    required this.segmentIndex,
    required this.normal,
    required this.correctedPosition,
    required this.contactPoint,
  });

  final int segmentIndex;
  final Vector2 normal;
  final Vector2 correctedPosition;
  final Vector2 contactPoint;
}

class ShieldPlayerBounce {
  static const double _epsilon = 1e-6;

  static ShieldPlayerCollision? resolve({
    required Vector2 center,
    required double outerRadius,
    required double angleOffset,
    required List<bool> destroyedSegments,
    required Vector2 playerPosition,
    required Vector2? previousPlayerPosition,
    required double playerRadius,
    required Vector2 velocity,
    double margin = 2,
    double? solidInnerRadius,
  }) {
    final sides = destroyedSegments.length;
    if (sides < 3) return null;

    final segmentSize = 2 * math.pi / sides;
    final separation = playerRadius + margin;
    ShieldPlayerCollision? firstCrossing;
    var firstCrossingTime = double.infinity;
    ShieldPlayerCollision? deepestOverlap;
    var deepestPenetration = 0.0;

    for (var index = 0; index < sides; index++) {
      if (destroyedSegments[index]) continue;

      final startAngle = angleOffset + index * segmentSize - math.pi / 2;
      final endAngle = angleOffset + (index + 1) * segmentSize - math.pi / 2;
      final start =
          center +
          Vector2(
            outerRadius * math.cos(startAngle),
            outerRadius * math.sin(startAngle),
          );
      final end =
          center +
          Vector2(
            outerRadius * math.cos(endAngle),
            outerRadius * math.sin(endAngle),
          );
      final edge = end - start;
      final edgeLengthSquared = edge.length2;
      if (edgeLengthSquared == 0) continue;

      final outward = Vector2(edge.y, -edge.x).normalized();
      final currentSignedDistance = (playerPosition - start).dot(outward);
      final previousSignedDistance = previousPlayerPosition == null
          ? currentSignedDistance
          : (previousPlayerPosition - start).dot(outward);

      final crossedEdge = solidInnerRadius == null
          ? previousSignedDistance * currentSignedDistance < 0
          : previousSignedDistance > 0 && currentSignedDistance < 0;
      if (previousPlayerPosition != null && crossedEdge) {
        final crossingTime =
            previousSignedDistance /
            (previousSignedDistance - currentSignedDistance);
        final crossingPoint =
            previousPlayerPosition +
            (playerPosition - previousPlayerPosition) * crossingTime;
        final edgeProjection =
            (crossingPoint - start).dot(edge) / edgeLengthSquared;
        final crossesOutsideSolidBoundary =
            solidInnerRadius == null ||
            crossingPoint.distanceTo(center) > solidInnerRadius;
        if (edgeProjection >= 0 &&
            edgeProjection <= 1 &&
            crossesOutsideSolidBoundary) {
          final normal = solidInnerRadius != null || previousSignedDistance > 0
              ? outward
              : -outward;
          if (crossingTime < firstCrossingTime) {
            firstCrossingTime = crossingTime;
            firstCrossing = ShieldPlayerCollision(
              segmentIndex: index,
              normal: normal,
              correctedPosition: crossingPoint + normal * separation,
              contactPoint: crossingPoint,
            );
          }
        }
      }

      final currentProjection =
          ((playerPosition - start).dot(edge) / edgeLengthSquared).clamp(
            0.0,
            1.0,
          );
      if (solidInnerRadius != null &&
          playerPosition.distanceTo(center) <= solidInnerRadius) {
        continue;
      }
      final edgeLength = math.sqrt(edgeLengthSquared);
      final isCornerContact =
          currentProjection * edgeLength <= playerRadius ||
          (1 - currentProjection) * edgeLength <= playerRadius;
      final closestPoint = currentProjection * edgeLength <= playerRadius
          ? start
          : (1 - currentProjection) * edgeLength <= playerRadius
          ? end
          : start + edge * currentProjection;
      final distance = playerPosition.distanceTo(closestPoint);
      final penetration = separation - distance;
      if (penetration <= _epsilon || penetration <= deepestPenetration) {
        continue;
      }

      var side = previousSignedDistance.abs() > _epsilon
          ? previousSignedDistance
          : currentSignedDistance;
      if (side.abs() <= _epsilon) {
        side = velocity.dot(outward) < 0 ? -1 : 1;
      }
      final normal = distance > _epsilon
          ? (playerPosition - closestPoint).normalized()
          : side > 0
          ? outward
          : -outward;
      final collisionNormal = solidInnerRadius != null
          ? isCornerContact && currentSignedDistance > 0
                ? normal
                : outward
          : isCornerContact
          ? normal
          : side > 0
          ? outward
          : -outward;
      deepestPenetration = penetration;
      deepestOverlap = ShieldPlayerCollision(
        segmentIndex: index,
        normal: collisionNormal,
        correctedPosition: closestPoint + collisionNormal * separation,
        contactPoint: closestPoint,
      );
    }

    return firstCrossing ?? deepestOverlap;
  }

  static Vector2 reflectVelocity(
    Vector2 velocity,
    Vector2 normal, {
    double restitution = 0.9,
    Vector2? surfaceVelocity,
  }) {
    final unitNormal = normal.normalized();
    final surface = surfaceVelocity ?? Vector2.zero();
    final relativeVelocity = velocity - surface;
    final normalSpeed = relativeVelocity.dot(unitNormal);
    if (normalSpeed >= 0) return velocity.clone();
    return relativeVelocity -
        unitNormal * ((1 + restitution) * normalSpeed) +
        surface;
  }

  static bool isTeleport({
    required Vector2 previousPosition,
    required Vector2 currentPosition,
    required double dt,
    required double maxSpeed,
    required double playerSize,
  }) {
    final maximumTravel = maxSpeed * 2 * dt + playerSize;
    return previousPosition.distanceTo(currentPosition) > maximumTravel;
  }
}
