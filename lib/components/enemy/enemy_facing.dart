import 'dart:math' as math;

import 'package:flame/components.dart';

double noseWorldAngle(double spriteAngle) => spriteAngle - math.pi / 2;

bool isAngleWithinNose(
  double spriteAngle,
  double worldAngle,
  double halfAngle,
) {
  final delta = _normalizeAngle(worldAngle - noseWorldAngle(spriteAngle));
  return delta.abs() <= halfAngle;
}

bool isPointInNoseCone(
  Vector2 origin,
  double spriteAngle,
  Vector2 point,
  double halfAngle,
) {
  final toPoint = point - origin;
  if (toPoint.length2 == 0) return false;
  final worldAngle = math.atan2(toPoint.y, toPoint.x);
  return isAngleWithinNose(spriteAngle, worldAngle, halfAngle);
}

double _normalizeAngle(double angle) {
  while (angle <= -math.pi) {
    angle += 2 * math.pi;
  }
  while (angle > math.pi) {
    angle -= 2 * math.pi;
  }
  return angle;
}