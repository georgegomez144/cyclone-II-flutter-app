import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Difficulty options
enum Difficulty { boring, challenging, frustrating }

class HighScoreEntry {
  HighScoreEntry({
    required this.name,
    required this.score,
    required this.level,
  });
  final String name;
  final int score;
  final int level;

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'level': level,
  };
  static HighScoreEntry fromJson(Map<String, dynamic> json) => HighScoreEntry(
    name: json['name'] as String? ?? 'Player',
    score: json['score'] as int? ?? 0,
    level: json['level'] as int? ?? 1,
  );
}

/// GameManager holds reactive game state, settings, and high scores.
enum BulletMode { single, auto, triple }

class GameManager {
  // Per-level time bonus countdown
  final levelBonus = ValueNotifier<int>(5000);
  // Gameplay state
  final score = ValueNotifier<int>(0);
  final lives = ValueNotifier<int>(3);
  final shields = ValueNotifier<double>(100);
  final currentLevel = ValueNotifier<int>(1);
  // Player firing mode for HUD
  final currentBulletMode = ValueNotifier<BulletMode>(BulletMode.single);
  // Persist yummies across death when true (granted by Lock Yummy)
  final keepYummiesOnDeath = ValueNotifier<bool>(false);

  // Timed weapon override: Triple + Continuous for a limited duration
  final tripleAutoRemaining = ValueNotifier<double>(
    0,
  ); // seconds left; 0=inactive
  bool tripleAutoActive = false;
  // Previous weapon state to restore after TripleAuto ends
  BulletMode prevBulletMode = BulletMode.single;
  bool prevHasContinuous = false;
  bool prevHasTriple = false;

  void startTripleAuto({
    required double durationSeconds,
    required void Function() applyToPlayer,
    required void Function() restorePlayer,
  }) {
    // Save previous weapon state for restore callback to use
    prevBulletMode = currentBulletMode.value;
    // Activate and set remaining time
    tripleAutoActive = true;
    tripleAutoRemaining.value = durationSeconds;
    // Apply immediate player changes via callback
    applyToPlayer();
  }

  void tickTripleAuto(double dt, {required void Function() restorePlayer}) {
    if (!tripleAutoActive) return;
    tripleAutoRemaining.value = (tripleAutoRemaining.value - dt).clamp(0, 600);
    if (tripleAutoRemaining.value <= 0) {
      tripleAutoActive = false;
      // Restore player state
      restorePlayer();
      // Restore HUD bullet mode to previous
      currentBulletMode.value = prevBulletMode;
    }
  }

  void cancelTripleAuto({required void Function() restorePlayer}) {
    if (!tripleAutoActive) return;
    tripleAutoActive = false;
    tripleAutoRemaining.value = 0;
    restorePlayer();
    currentBulletMode.value = prevBulletMode;
  }

  // Settings/state
  final difficulty = ValueNotifier<Difficulty>(Difficulty.challenging);
  final volume = ValueNotifier<double>(0.8);
  final lastPlayerName = ValueNotifier<String>('Player');
  final lastScore = ValueNotifier<int>(0);
  final lastLevel = ValueNotifier<int>(1);

  // High scores (max 5)
  final highScores = ValueNotifier<List<HighScoreEntry>>(<HighScoreEntry>[]);

  static const _prefsKeyScores = 'high_scores_v1';
  static const _prefsKeyPlayer = 'last_player_v1';
  static const _prefsKeyLastScore = 'last_score_v1';
  static const _prefsKeyLastLevel = 'last_level_v1';
  static const _prefsKeyVolume = 'volume_v1';
  static const _prefsKeyDifficulty = 'difficulty_v1';

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresStr = prefs.getString(_prefsKeyScores);
      if (scoresStr != null) {
        final List list = jsonDecode(scoresStr) as List;
        highScores.value = list
            .map(
              (e) =>
                  HighScoreEntry.fromJson((e as Map).cast<String, dynamic>()),
            )
            .take(5)
            .toList(growable: false);
      }
      lastPlayerName.value =
          prefs.getString(_prefsKeyPlayer) ?? lastPlayerName.value;
      lastScore.value = prefs.getInt(_prefsKeyLastScore) ?? lastScore.value;
      lastLevel.value = prefs.getInt(_prefsKeyLastLevel) ?? lastLevel.value;
      volume.value = prefs.getDouble(_prefsKeyVolume) ?? volume.value;
      final diffIdx = prefs.getInt(_prefsKeyDifficulty);
      if (diffIdx != null &&
          diffIdx >= 0 &&
          diffIdx < Difficulty.values.length) {
        difficulty.value = Difficulty.values[diffIdx];
      }
    } on MissingPluginException catch (e) {
      debugPrint('SharedPreferences MissingPluginException: ${e.message}');
      // Continue with defaults; likely hot-restart on iOS/macOS. A full restart fixes this.
    } on PlatformException catch (e) {
      debugPrint('SharedPreferences PlatformException: $e');
    } catch (e) {
      debugPrint('SharedPreferences load error: $e');
    }
  }

  Future<void> savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyScores,
        jsonEncode(highScores.value.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_prefsKeyPlayer, lastPlayerName.value);
      await prefs.setInt(_prefsKeyLastScore, lastScore.value);
      await prefs.setInt(_prefsKeyLastLevel, lastLevel.value);
      await prefs.setDouble(_prefsKeyVolume, volume.value);
      await prefs.setInt(_prefsKeyDifficulty, difficulty.value.index);
    } on MissingPluginException catch (e) {
      debugPrint(
        'SharedPreferences MissingPluginException on save: ${e.message}',
      );
    } on PlatformException catch (e) {
      debugPrint('SharedPreferences PlatformException on save: $e');
    } catch (e) {
      debugPrint('SharedPreferences save error: $e');
    }
  }

  // Save only the leaderboard-related fields: player name, score, level, and list
  Future<void> saveScoresOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyScores,
        jsonEncode(highScores.value.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_prefsKeyPlayer, lastPlayerName.value);
      await prefs.setInt(_prefsKeyLastScore, lastScore.value);
      await prefs.setInt(_prefsKeyLastLevel, lastLevel.value);
    } on MissingPluginException catch (e) {
      debugPrint(
        'SharedPreferences MissingPluginException (scores only): ${e.message}',
      );
    } on PlatformException catch (e) {
      debugPrint('SharedPreferences PlatformException (scores only): $e');
    } catch (e) {
      debugPrint('SharedPreferences save error (scores only): $e');
    }
  }

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

  void gainLife({int amount = 1, int maxLives = 9}) {
    final next = (lives.value + amount).clamp(0, maxLives);
    lives.value = next;
  }

  void resetForNewGame() {
    score.value = 0;
    lives.value = 3;
    shields.value = 100;
    currentLevel.value = 1;

    // Reset HUD + weapon/power-up model state
    currentBulletMode.value = BulletMode.single;
    keepYummiesOnDeath.value = false; // Lock Yummy cleared at new game

    // Fully cancel any active TripleAuto override and its timers
    tripleAutoActive = false;
    tripleAutoRemaining.value = 0;
    prevBulletMode = BulletMode.single;
    prevHasContinuous = false;
    prevHasTriple = false;
  }

  void submitHighScore({required int level}) {
    lastScore.value = score.value;
    lastLevel.value = level;
    final entry = HighScoreEntry(
      name: lastPlayerName.value,
      score: lastScore.value,
      level: lastLevel.value,
    );
    final list = [...highScores.value, entry];
    list.sort((a, b) => b.score.compareTo(a.score));
    highScores.value = list.take(5).toList(growable: false);
    // Only persist name, score, and level on game over
    saveScoresOnly();
  }

  void clearHighScores() {
    highScores.value = <HighScoreEntry>[];
    savePrefs();
  }
}
