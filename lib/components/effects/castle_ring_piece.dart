import 'package:flutter/material.dart';

class CastleRingSnapshot {
  CastleRingSnapshot({
    required this.outerRadius,
    required this.angleOffset,
    required this.angularVelocity,
    required this.color,
    required this.glowColor,
    required List<bool> destroyedSegments,
  }) : destroyedSegments = List<bool>.unmodifiable(destroyedSegments);

  final double outerRadius;
  final double angleOffset;
  final double angularVelocity;
  final Color color;
  final Color glowColor;
  final List<bool> destroyedSegments;
}

class CastleRingPiece {
  CastleRingPiece({required this.ring, required this.segmentIndex});

  final CastleRingSnapshot ring;
  final int segmentIndex;
  double? detachedAt;
  late double detachedAngle;
  late double directionAngle;
}
