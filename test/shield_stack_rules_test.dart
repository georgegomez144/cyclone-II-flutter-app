import 'package:cyclone_game/components/player/shield_stack_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShieldStackRules', () {
    test('collects shields up to the three-shield cap', () {
      expect(ShieldStackRules.collect(0), 100);
      expect(ShieldStackRules.collect(200), 300);
      expect(ShieldStackRules.collect(300), 300);
    });

    test('consuming a partially damaged top layer removes only that layer', () {
      expect(ShieldStackRules.consumeOne(275), 200);
      expect(ShieldStackRules.consumeOne(100), 0);
    });

    test('damage reduces the top layer and lowers the count when depleted', () {
      final damaged = ShieldStackRules.damage(300, 25);

      expect(damaged, 275);
      expect(ShieldStackRules.topLayerStrength(damaged), 75);
      expect(ShieldStackRules.countFor(damaged), 3);

      final depletedTopLayer = ShieldStackRules.damage(damaged, 75);
      expect(depletedTopLayer, 200);
      expect(ShieldStackRules.countFor(depletedTopLayer), 2);
    });

    test('handles zero strength', () {
      expect(ShieldStackRules.countFor(0), 0);
      expect(ShieldStackRules.topLayerStrength(0), 0);
      expect(ShieldStackRules.consumeOne(0), 0);
      expect(ShieldStackRules.damage(0, 25), 0);
    });
  });
}
