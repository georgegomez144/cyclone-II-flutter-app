import 'dart:math' as math;

import 'package:cyclone_game/components/effects/castle_destruction.dart';
import 'package:cyclone_game/components/effects/castle_ring_piece.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CastleDestruction', () {
    CastleRingSnapshot ring({List<int> intactSegments = const [0, 1, 2]}) {
      final destroyed = List<bool>.filled(12, true);
      for (final index in intactSegments) {
        destroyed[index] = false;
      }
      return CastleRingSnapshot(
        outerRadius: 60,
        angleOffset: 0,
        angularVelocity: 1,
        color: Colors.red,
        glowColor: Colors.orange,
        destroyedSegments: destroyed,
      );
    }

    CastleDestruction effect({
      required List<CastleRingSnapshot> rings,
      double segmentPhase = 1,
      VoidCallback? onShipExploded,
    }) => CastleDestruction(
      rings: rings,
      shipSprite: null,
      shipSize: Vector2.all(60),
      shipAngle: 0,
      maxRadius: 100,
      segmentPhase: segmentPhase,
      onShipExploded: onShipExploded,
      random: math.Random(1),
    );

    test('creates pieces only for segments that were intact', () {
      final destruction = effect(
        rings: [
          ring(intactSegments: [2, 7]),
        ],
      );

      expect(destruction.pieceCount, 2);
    });

    test('detaches pieces one at a time over the phase', () {
      final destruction = effect(
        rings: [
          ring(intactSegments: [0, 1, 2, 3]),
        ],
      );

      destruction.update(0);
      expect(destruction.explodedPieceCount, 1);

      destruction.update(0.24);
      expect(destruction.explodedPieceCount, 1);

      destruction.update(0.02);
      expect(destruction.explodedPieceCount, 2);
    });

    test('destroys the ship only after the final segment detaches', () {
      final destruction = effect(
        rings: [
          ring(intactSegments: [0, 1, 2]),
        ],
        segmentPhase: 0.6,
      );

      destruction.update(0.5);
      expect(destruction.explodedPieceCount, 3);
      expect(destruction.isShipDestroyed, isFalse);

      destruction.update(0.14);
      expect(destruction.isShipDestroyed, isFalse);
      destruction.update(0.02);
      expect(destruction.isShipDestroyed, isTrue);
    });

    test('fires the final callback once and eventually finishes', () {
      var callbackCount = 0;
      final destruction = effect(
        rings: [ring()],
        onShipExploded: () => callbackCount++,
      );

      destruction.update(2);
      destruction.update(1);

      expect(callbackCount, 1);
      expect(destruction.isShipDestroyed, isTrue);
      expect(destruction.isFinished, isTrue);
    });

    test('still runs the ship explosion when the shield has no rings', () {
      final destruction = effect(rings: const []);

      destruction.update(0.7);

      expect(destruction.pieceCount, 0);
      expect(destruction.isShipDestroyed, isTrue);
    });
  });
}
