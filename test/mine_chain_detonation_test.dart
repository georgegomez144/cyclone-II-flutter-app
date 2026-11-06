import 'package:cyclone_game/components/effects/mine_chain_detonation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MineChainDetonation', () {
    test('fires the first mine immediately', () {
      final detonated = <int>[];
      final chain = MineChainDetonation(
        count: 3,
        interval: 0.2,
        onDetonate: detonated.add,
      );

      chain.update(0);

      expect(detonated, [0]);
      expect(chain.detonatedCount, 1);
    });

    test('stagger fires by index once and finishes', () {
      final detonated = <int>[];
      final chain = MineChainDetonation(
        count: 3,
        interval: 0.2,
        onDetonate: detonated.add,
      );

      chain.update(0);
      chain.update(0.19);
      expect(detonated, [0]);

      chain.update(0.01);
      expect(detonated, [0, 1]);

      chain.update(0.4);
      chain.update(1);
      expect(detonated, [0, 1, 2]);
      expect(chain.detonatedCount, 3);
      expect(chain.isFinished, isTrue);
    });

    test('zero count is finished immediately', () {
      final chain = MineChainDetonation(
        count: 0,
        interval: 0.15,
        onDetonate: (_) => fail('No mine should detonate'),
      );

      expect(chain.detonatedCount, 0);
      expect(chain.isFinished, isTrue);
      chain.update(1);
      expect(chain.detonatedCount, 0);
    });
  });
}
