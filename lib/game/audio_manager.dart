import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cyclone_game/generated/assets.dart';

/// Centralized audio manager for SFX and background loop.
/// - Provides a global enable/disable toggle persisted with SharedPreferences.
/// - Uses FlameAudio for SFX playback and BGM looping.
class AudioManager {
  AudioManager._internal();
  static final AudioManager instance = AudioManager._internal();

  // Track last play errors to avoid spamming retries/logs for missing assets
  static final Map<String, DateTime> _lastPlayErrorAt = <String, DateTime>{};
  static const Duration _retryBackoff = Duration(seconds: 5);

  static const _prefsKeySfxEnabled = 'sfx_enabled_v1';

  /// Whether SFX/BGM are enabled.
  final ValueListenable<bool> sfxEnabled = _sfxEnabledNotifier;
  static final ValueNotifier<bool> _sfxEnabledNotifier = ValueNotifier<bool>(
    true,
  );

  bool get isEnabled => _sfxEnabledNotifier.value;

  // Convert various asset path inputs to the filename expected by
  // FlameAudio when using a fixed AudioCache prefix (see init()).
  // Examples:
  //  - 'background_hum.mp3'           -> 'background_hum.mp3'
  //  - 'lib/assets/audio/foo.mp3'     -> 'foo.mp3'
  //  - 'assets/audio/bar.mp3'         -> 'bar.mp3'
  String _toAudioKey(String assetPath) {
    final parts = assetPath.split('/');
    return parts.isNotEmpty ? parts.last : assetPath;
  }

  Future<void> init() async {
    // Load persisted toggle
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsKeySfxEnabled);
      if (enabled != null) {
        _sfxEnabledNotifier.value = enabled;
      }
    } catch (_) {
      // ignore persistence errors
    }

    // Ensure AudioCache prefix is consistent on all platforms.
    // We always pass bare filenames like 'background_hum.mp3'.
    FlameAudio.audioCache.prefix = 'lib/assets/audio/';

    // Optionally initialize BGM subsystem (no-op if already initialized).
    try {
      // Some environments require calling initialize before play/resume.
      // ignore: discarded_futures
      FlameAudio.bgm.initialize();
    } catch (_) {}

    // Pre-cache commonly used audio files (pass keys without the default prefix)
    final keys = <String>[
      _toAudioKey('background_hum.mp3'),
      _toAudioKey('begin.mp3'),
      _toAudioKey('enemy_blast.mp3'),
      _toAudioKey('enemy_explode.mp3'),
      _toAudioKey('player_shot.mp3'),
      _toAudioKey('player_explode.mp3'),
      _toAudioKey('mine_buzzing.mp3'),
      _toAudioKey('mine_explode.mp3'),
      _toAudioKey('yummy_fx.mp3'),
      _toAudioKey('dont_want_it.mp3'),
      _toAudioKey('you_lose.mp3'),
    ];

    // Load each asset defensively so a single failure doesn't crash startup.
    for (final k in keys) {
      try {
        await FlameAudio.audioCache.load(k);
      } catch (e) {
        // Swallow and continue; we'll attempt lazy-load on first play.
        // debug print for visibility during development
        // ignore: avoid_print
        print('Audio pre-cache failed for "$k": $e');
      }
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_sfxEnabledNotifier.value == enabled) return;
    _sfxEnabledNotifier.value = enabled;
    // Persist
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeySfxEnabled, enabled);
    } catch (_) {}

    // Reflect on BGM
    if (enabled) {
      // If BGM was supposed to be playing, resume will be handled by caller.
      // Do nothing here.
    } else {
      // Stop any active BGM and SFX loops
      await FlameAudio.bgm.stop();
    }
  }

  // --- BGM (background hum) -------------------------------------------------
  Future<void> playBackgroundHum({double volume = 0.25}) async {
    if (!isEnabled) return;
    // Ensure BGM uses the background hum and loops
    await FlameAudio.bgm.stop();
    try {
      await FlameAudio.bgm.play(
        _toAudioKey(Assets.audioBackgroundHum),
        volume: volume,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('BGM play failed for "${_toAudioKey('background_hum.mp3')}": $e');
      }
    }
  }

  Future<void> stopBackgroundHum() async {
    await FlameAudio.bgm.stop();
  }

  Future<void> pauseBackgroundHum() async {
    await FlameAudio.bgm.pause();
  }

  Future<void> resumeBackgroundHum() async {
    if (!isEnabled) return;
    try {
      await FlameAudio.bgm.resume();
    } catch (_) {
      // If resume fails (e.g., nothing loaded), start playing again.
      await playBackgroundHum();
    }
  }

  // --- SFX helpers ----------------------------------------------------------
  void playBegin() {
    _play(_toAudioKey('begin.mp3'), volume: 0.9);
  }

  void playEnemyBlast() {
    _play(_toAudioKey('enemy_blast.mp3'), volume: 0.7);
  }

  void playEnemyExplode() {
    _play(_toAudioKey('enemy_explode.mp3'), volume: 0.9);
  }

  void playPlayerShot() {
    _play(_toAudioKey('player_shot.mp3'), volume: 0.7);
  }

  void playPlayerExplode() {
    _play(_toAudioKey('player_explode.mp3'), volume: 0.9);
  }

  void playMineBuzz() {
    // very quiet single-shot buzz (for per-frame loop callers avoid spamming)
    _play(_toAudioKey('mine_buzzing.mp3'), volume: 0.15);
  }

  void playMineExplode() {
    _play(_toAudioKey('mine_explode.mp3'), volume: 0.7);
  }

  void playYummyPickup() {
    _play(_toAudioKey('yummy_fx.mp3'), volume: 0.8);
  }

  void playYummyDiscard() {
    _play(_toAudioKey('dont_want_it.mp3'), volume: 0.6);
  }

  void playGameOver() {
    _play(_toAudioKey('you_lose.mp3'), volume: 0.9);
  }

  void _play(String file, {double volume = 1.0}) {
    if (!isEnabled) return;

    // Simple backoff if we recently failed to play this key (prevents log spam)
    final lastErr = _lastPlayErrorAt[file];
    if (lastErr != null && DateTime.now().difference(lastErr) < _retryBackoff) {
      return;
    }

    try {
      FlameAudio.play(file, volume: volume);
    } catch (e) {
      _lastPlayErrorAt[file] = DateTime.now();
      if (kDebugMode) {
        // ignore: avoid_print
        print('SFX play failed for "$file": $e');
      }
    }
  }
}
