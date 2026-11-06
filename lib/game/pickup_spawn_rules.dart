import 'dart:math' as math;

class PickupSpawnRules {
  static bool canSpawnFlare({
    required int level,
    required bool levelTransitioning,
  }) => level > 14 && !levelTransitioning;

  static double intervalForLevel(int level) {
    final steps = ((level - 1) ~/ 10).clamp(0, 1000).toInt();
    final frequencyMultiplier = 1.10 + 0.02 * steps;
    return 10.0 / frequencyMultiplier;
  }

  static bool hazardsDestroyYummies(int level) => level > 149;

  static double nextInterval(int level, math.Random rnd) {
    final baseInterval = intervalForLevel(level);
    if (level <= 149) return baseInterval;
    return baseInterval / 2 * (0.5 + rnd.nextDouble());
  }

  static int maxConcurrent(int level) => level > 149 ? 4 : 2;
}
