import 'dart:math' as math;

class ShieldRingSnapshot {
  const ShieldRingSnapshot({
    required this.outerRadius,
    required this.innerRadius,
    required this.angleOffset,
    required this.angularVelocity,
    required this.destroyedSegments,
  });

  final double outerRadius;
  final double innerRadius;
  final double angleOffset;
  final double angularVelocity;
  final List<bool> destroyedSegments;
}

class ShieldFireSolver {
  static const int sides = 12;
  static const double _angleStep = math.pi / 720;
  static const double _pathStep = 1.0;

  static double normalizeAngle(double angle) {
    var normalized = angle % (2 * math.pi);
    if (normalized <= -math.pi) normalized += 2 * math.pi;
    if (normalized > math.pi) normalized -= 2 * math.pi;
    return normalized;
  }

  static int segmentIndexAt(
    double worldAngle,
    double angleOffset, {
    int segmentCount = sides,
  }) {
    final segmentSize = 2 * math.pi / segmentCount;
    var localAngle = (worldAngle - angleOffset + math.pi / 2) % (2 * math.pi);
    if (localAngle < 0) localAngle += 2 * math.pi;
    return (localAngle / segmentSize).floor() % segmentCount;
  }

  static double? findSafeAngle({
    required List<ShieldRingSnapshot> rings,
    required double targetAngle,
    required double spawnDistance,
    required double speed,
    required double baseRadius,
    required double growthPerSecond,
    required double leadTime,
    required double maxDeviation,
    required double margin,
  }) {
    if (rings.isEmpty || speed <= 0 || growthPerSecond <= 0) return null;

    final maxSteps = (maxDeviation.abs() / _angleStep).floor();
    for (var step = 0; step <= maxSteps; step++) {
      final deviations = step == 0
          ? const [0.0]
          : <double>[_angleStep * step, -_angleStep * step];
      for (final deviation in deviations) {
        final candidate = normalizeAngle(targetAngle + deviation);
        if (!_passesOpeningPrefilter(
          rings,
          candidate,
          spawnDistance,
          speed,
          leadTime,
        )) {
          continue;
        }
        if (pathIsClear(
          rings: rings,
          angle: candidate,
          spawnDistance: spawnDistance,
          speed: speed,
          baseRadius: baseRadius,
          growthPerSecond: growthPerSecond,
          leadTime: leadTime,
          margin: margin,
        )) {
          return candidate;
        }
      }
    }
    return null;
  }

  static bool pathIsClear({
    required List<ShieldRingSnapshot> rings,
    required double angle,
    required double spawnDistance,
    required double speed,
    required double baseRadius,
    required double growthPerSecond,
    required double leadTime,
    required double margin,
  }) {
    if (speed <= 0 || growthPerSecond <= 0) return false;
    final furthestRing = rings.fold<double>(
      0,
      (furthest, ring) => math.max(furthest, ring.outerRadius).toDouble(),
    );
    if (furthestRing <= spawnDistance) return true;

    var endTime = (furthestRing + baseRadius + margin - spawnDistance) / speed;
    for (var iteration = 0; iteration < 4; iteration++) {
      final grownRadius =
          baseRadius * math.pow(growthPerSecond, endTime) + margin;
      endTime = (furthestRing + grownRadius - spawnDistance) / speed;
    }
    final sampleCount = math
        .max(1, (endTime * speed / _pathStep).ceil())
        .toInt();
    final unitX = math.cos(angle);
    final unitY = math.sin(angle);

    for (var sample = 0; sample <= sampleCount; sample++) {
      final distance = spawnDistance + (endTime * speed * sample / sampleCount);
      final time = (distance - spawnDistance) / speed;
      final blastRadius = baseRadius * math.pow(growthPerSecond, time) + margin;
      final pointX = unitX * distance;
      final pointY = unitY * distance;

      for (final ring in rings) {
        if (distance + blastRadius < ring.innerRadius ||
            distance - blastRadius > ring.outerRadius) {
          continue;
        }
        final predictedOffset =
            ring.angleOffset + ring.angularVelocity * (leadTime + time);
        if (_intersectsIntactSegment(
          pointX,
          pointY,
          blastRadius,
          ring,
          predictedOffset,
        )) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _passesOpeningPrefilter(
    List<ShieldRingSnapshot> rings,
    double angle,
    double spawnDistance,
    double speed,
    double leadTime,
  ) {
    for (final ring in rings) {
      if (ring.outerRadius <= spawnDistance) continue;
      final crossingTime = (ring.outerRadius - spawnDistance) / speed;
      final offset =
          ring.angleOffset + ring.angularVelocity * (leadTime + crossingTime);
      final index = segmentIndexAt(angle, offset);
      if (index >= ring.destroyedSegments.length ||
          !ring.destroyedSegments[index]) {
        return false;
      }
    }
    return true;
  }

  static bool _intersectsIntactSegment(
    double pointX,
    double pointY,
    double radius,
    ShieldRingSnapshot ring,
    double angleOffset,
  ) {
    final segmentSize = 2 * math.pi / ring.destroyedSegments.length;
    for (var index = 0; index < ring.destroyedSegments.length; index++) {
      if (ring.destroyedSegments[index]) continue;

      final startAngle = angleOffset + index * segmentSize - math.pi / 2;
      final endAngle = startAngle + segmentSize;
      final innerStart = _pointAt(ring.innerRadius, startAngle);
      final innerEnd = _pointAt(ring.innerRadius, endAngle);
      final outerStart = _pointAt(ring.outerRadius, startAngle);
      final outerEnd = _pointAt(ring.outerRadius, endAngle);

      if (_pointInQuad(
        pointX,
        pointY,
        innerStart,
        innerEnd,
        outerEnd,
        outerStart,
      )) {
        return true;
      }
      if (_distanceToSegment(pointX, pointY, outerStart, outerEnd) <= radius ||
          _distanceToSegment(pointX, pointY, innerStart, innerEnd) <= radius ||
          _distanceToSegment(pointX, pointY, innerStart, outerStart) <=
              radius ||
          _distanceToSegment(pointX, pointY, innerEnd, outerEnd) <= radius) {
        return true;
      }
    }
    return false;
  }

  static (double, double) _pointAt(double radius, double angle) =>
      (radius * math.cos(angle), radius * math.sin(angle));

  static double _distanceToSegment(
    double px,
    double py,
    (double, double) start,
    (double, double) end,
  ) {
    final dx = end.$1 - start.$1;
    final dy = end.$2 - start.$2;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return math.sqrt(math.pow(px - start.$1, 2) + math.pow(py - start.$2, 2));
    }
    final projection =
        (((px - start.$1) * dx + (py - start.$2) * dy) / lengthSquared).clamp(
          0.0,
          1.0,
        );
    final closestX = start.$1 + projection * dx;
    final closestY = start.$2 + projection * dy;
    return math.sqrt(math.pow(px - closestX, 2) + math.pow(py - closestY, 2));
  }

  static bool _pointInQuad(
    double px,
    double py,
    (double, double) a,
    (double, double) b,
    (double, double) c,
    (double, double) d,
  ) {
    final points = [a, b, c, d];
    var hasPositive = false;
    var hasNegative = false;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final cross =
          (next.$1 - current.$1) * (py - current.$2) -
          (next.$2 - current.$2) * (px - current.$1);
      if (cross > 1e-9) hasPositive = true;
      if (cross < -1e-9) hasNegative = true;
      if (hasPositive && hasNegative) return false;
    }
    return true;
  }
}
