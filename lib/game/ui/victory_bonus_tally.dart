import 'dart:math' as math;

import 'package:cyclone_game/game/bonus_tally.dart';
import 'package:cyclone_game/game/number_format.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class VictoryBonusTally extends PositionComponent {
  VictoryBonusTally({
    required int total,
    required double duration,
    required double startDelay,
    required int score,
    required int lives,
    required this.onAddScore,
    required this.onComplete,
  }) : _tally = BonusTally(total: total, duration: duration),
       _delayRemaining = startDelay,
       _score = score,
       _lives = lives {
    if (!startDelay.isFinite || startDelay < 0) {
      throw ArgumentError.value(
        startDelay,
        'startDelay',
        'Must not be negative',
      );
    }
    _bonusText = TextComponent(
      text: 'Bonus: ${formatWithCommas(_tally.remaining)}',
      anchor: Anchor.center,
      position: Vector2(0, -12),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _summaryText = TextComponent(
      text: 'Score: ${formatWithCommas(score)}   Ships: $lives',
      anchor: Anchor.center,
      position: Vector2(0, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    addAll([_bonusText, _summaryText]);
  }

  final BonusTally _tally;
  final void Function(int points) onAddScore;
  final void Function() onComplete;
  final int _lives;
  late final TextComponent _bonusText;
  late final TextComponent _summaryText;
  double _delayRemaining;
  int _score;
  bool _completed = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_completed) return;
    if (_tally.isDone) {
      _complete();
      return;
    }

    var tallyDt = dt;
    if (_delayRemaining > 0) {
      final delayStep = math.min(tallyDt, _delayRemaining).toDouble();
      _delayRemaining -= delayStep;
      tallyDt -= delayStep;
    }
    if (tallyDt <= 0) return;

    final points = _tally.step(tallyDt);
    if (points > 0) {
      _score += points;
      onAddScore(points);
    }
    _updateText();
    if (_tally.isDone) _complete();
  }

  int flush() {
    final points = _tally.finish();
    if (points > 0) {
      _score += points;
      onAddScore(points);
    }
    _updateText();
    _complete();
    return points;
  }

  void _updateText() {
    _bonusText.text = 'Bonus: ${formatWithCommas(_tally.remaining)}';
    _summaryText.text = 'Score: ${formatWithCommas(_score)}   Ships: $_lives';
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    onComplete();
  }
}
