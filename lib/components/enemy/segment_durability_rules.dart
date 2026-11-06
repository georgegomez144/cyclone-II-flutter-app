class SegmentDurabilityRules {
  static int hitsToDestroy(int level) {
    if (level >= 200) return 5;
    if (level >= 150) return 4;
    if (level >= 100) return 3;
    return 2;
  }
}
