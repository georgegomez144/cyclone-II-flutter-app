import 'package:flutter/foundation.dart';

/// GameManager holds reactive game state for HUD bindings.
class GameManager {
  final score = ValueNotifier<int>(0);
  final lives = ValueNotifier<int>(3);
  final shields = ValueNotifier<double>(100);

  void addScore(int base, {int multiplier = 1}) {
    score.value += base * multiplier;
  }

  void damageShield(double amount) {
    shields.value = (shields.value - amount).clamp(0, 100);
  }

  void refillShield(double amount) {
    shields.value = (shields.value + amount).clamp(0, 100);
  }

  void loseLife() {
    if (lives.value > 0) {
      lives.value = lives.value - 1;
    }
  }
}
