import 'package:cyclone_game/game/bonus_tally.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BonusTally', () {
    test('transfers the full bonus over its duration', () {
      final tally = BonusTally(total: 100, duration: 1);
      var transferred = 0;

      for (var i = 0; i < 10; i++) {
        transferred += tally.step(0.1);
      }

      expect(transferred, 100);
      expect(tally.remaining, 0);
      expect(tally.isDone, isTrue);
    });

    test('finishes exactly at the duration', () {
      final tally = BonusTally(total: 10, duration: 1);

      expect(tally.step(0.99), 9);
      expect(tally.isDone, isFalse);
      expect(tally.step(0.01), 1);
      expect(tally.isDone, isTrue);
    });

    test('zero bonus is already done', () {
      final tally = BonusTally(total: 0, duration: 1);

      expect(tally.isDone, isTrue);
      expect(tally.step(1), 0);
      expect(tally.remaining, 0);
    });

    test('finish returns the remaining bonus exactly once', () {
      final tally = BonusTally(total: 10, duration: 1);
      tally.step(0.4);

      expect(tally.finish(), 6);
      expect(tally.finish(), 0);
      expect(tally.remaining, 0);
      expect(tally.isDone, isTrue);
    });

    test('large time steps do not transfer more than the bonus', () {
      final tally = BonusTally(total: 10, duration: 1);

      expect(tally.step(10), 10);
      expect(tally.step(10), 0);
      expect(tally.remaining, 0);
    });
  });
}
