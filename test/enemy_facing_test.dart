import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/enemy_facing.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enemy nose direction', () {
    test('maps sprite angle to the world-space nose angle', () {
      expect(noseWorldAngle(0), -math.pi / 2);
      expect(noseWorldAngle(math.pi / 2), 0);
    });

    test('includes points ahead and excludes points behind or to the side', () {
      final origin = Vector2.zero();
      const spriteAngle = 0.0;
      const halfAngle = math.pi / 12;

      expect(
        isPointInNoseCone(origin, spriteAngle, Vector2(0, -10), halfAngle),
        isTrue,
      );
      expect(
        isPointInNoseCone(origin, spriteAngle, Vector2(0, 10), halfAngle),
        isFalse,
      );
      expect(
        isPointInNoseCone(origin, spriteAngle, Vector2(10, 0), halfAngle),
        isFalse,
      );
    });

    test('handles angle wrap-around near positive and negative pi', () {
      final spriteAngle = 3 * math.pi / 2 - 0.02;

      expect(
        isAngleWithinNose(spriteAngle, -math.pi + 0.02, 0.05),
        isTrue,
      );
    });
  });
}