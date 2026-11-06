class ShieldStackRules {
  static const int maxShields = 3;
  static const double strengthPerShield = 100;
  static const double maxStrength = maxShields * strengthPerShield;

  static double collect(double strength) =>
      (strength + strengthPerShield).clamp(0, maxStrength).toDouble();

  static double consumeOne(double strength) {
    final count = countFor(strength);
    if (count == 0) return 0;
    return (count - 1) * strengthPerShield;
  }

  static double damage(double strength, double amount) {
    final current = strength.clamp(0, maxStrength).toDouble();
    if (amount <= 0) return current;
    return (current - amount).clamp(0, maxStrength).toDouble();
  }

  static int countFor(double strength) =>
      (strength.clamp(0, maxStrength) / strengthPerShield).ceil();

  static double topLayerStrength(double strength) {
    final current = strength.clamp(0, maxStrength).toDouble();
    final count = countFor(current);
    if (count == 0) return 0;
    return current - (count - 1) * strengthPerShield;
  }
}
