class PickupSpawnRules {
  static double intervalForLevel(int level) {
    final steps = ((level - 1) ~/ 10).clamp(0, 1000).toInt();
    final frequencyMultiplier = 1.10 + 0.02 * steps;
    return 10.0 / frequencyMultiplier;
  }
}
