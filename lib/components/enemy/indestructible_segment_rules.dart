import 'dart:math' as math;

class IndestructibleSegmentRules {
  static const int minLevel = 100;
  static const double minChance = 0.01;
  static const double maxChance = 0.05;

  static List<List<bool>> roll({
    required int level,
    required int ringCount,
    required int sides,
    required math.Random random,
  }) {
    final segments = List.generate(
      ringCount,
      (_) => List<bool>.filled(sides, false),
    );
    if (level < minLevel || sides <= 0) return segments;

    final chance = minChance + random.nextDouble() * (maxChance - minChance);
    for (final ring in segments) {
      for (var i = 0; i < ring.length; i++) {
        ring[i] = random.nextDouble() < chance;
      }
      if (ring.every((indestructible) => indestructible)) {
        ring[random.nextInt(sides)] = false;
      }
    }
    return segments;
  }
}
