import 'package:cyclone_game/game/pickup_collect_rules.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PickupCollectRules', () {
    test('uses the sum of sprite radii for desktop ship and pickup', () {
      expect(PickupCollectRules.shipCollectDistance(52, 54), 53);
    });

    test('collects within the widened radius but not beyond it', () {
      final playerPosition = Vector2.zero();
      expect(
        PickupCollectRules.canShipCollect(
          playerPosition,
          Vector2(50, 0),
          52,
          54,
        ),
        isTrue,
      );
      expect(
        PickupCollectRules.canShipCollect(
          playerPosition,
          Vector2(60, 0),
          52,
          54,
        ),
        isFalse,
      );
    });

    test('collects at the exact radius boundary', () {
      expect(
        PickupCollectRules.canShipCollect(
          Vector2.zero(),
          Vector2(53, 0),
          52,
          54,
        ),
        isTrue,
      );
    });

    test('uses the smaller phone ship size', () {
      expect(PickupCollectRules.shipCollectDistance(44, 54), 49);
    });
  });
}
