import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/shield_player_bounce.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const radius = 100.0;
  const playerRadius = 10.0;
  const margin = 2.0;
  final intactSegments = List<bool>.filled(12, false);

  Vector2 edgePoint(int index) {
    final segmentSize = 2 * math.pi / 12;
    final startAngle = index * segmentSize - math.pi / 2;
    final endAngle = (index + 1) * segmentSize - math.pi / 2;
    final start = Vector2(
      radius * math.cos(startAngle),
      radius * math.sin(startAngle),
    );
    final end = Vector2(
      radius * math.cos(endAngle),
      radius * math.sin(endAngle),
    );
    return (start + end) / 2;
  }

  Vector2 outwardNormal(int index) {
    final segmentSize = 2 * math.pi / 12;
    final startAngle = index * segmentSize - math.pi / 2;
    final endAngle = (index + 1) * segmentSize - math.pi / 2;
    final start = Vector2(
      radius * math.cos(startAngle),
      radius * math.sin(startAngle),
    );
    final end = Vector2(
      radius * math.cos(endAngle),
      radius * math.sin(endAngle),
    );
    final edge = end - start;
    return Vector2(edge.y, -edge.x).normalized();
  }

  ShieldPlayerCollision? resolveAt({
    required Vector2 current,
    required Vector2? previous,
    required Vector2 velocity,
    List<bool>? destroyed,
    double? solidInnerRadius,
  }) {
    return ShieldPlayerBounce.resolve(
      center: Vector2.zero(),
      outerRadius: radius,
      angleOffset: 0,
      destroyedSegments: destroyed ?? intactSegments,
      playerPosition: current,
      previousPlayerPosition: previous,
      playerRadius: playerRadius,
      velocity: velocity,
      margin: margin,
      solidInnerRadius: solidInnerRadius,
    );
  }

  group('ShieldPlayerBounce', () {
    test('bounces toward the outside when approaching from outside', () {
      final point = edgePoint(0);
      final outward = outwardNormal(0);
      final collision = resolveAt(
        current: point + outward * (playerRadius + margin - 1),
        previous: point + outward * 30,
        velocity: -outward * 100,
      );

      expect(collision, isNotNull);
      expect(collision!.segmentIndex, 0);
      expect(collision.normal.dot(outward), closeTo(1, 1e-6));
      expect(
        (collision.correctedPosition - point).dot(outward),
        closeTo(playerRadius + margin, 1e-5),
      );
    });

    test('bounces toward the inside when approaching from inside', () {
      final point = edgePoint(0);
      final outward = outwardNormal(0);
      final collision = resolveAt(
        current: point - outward * (playerRadius + margin - 1),
        previous: point - outward * 30,
        velocity: outward * 100,
      );

      expect(collision, isNotNull);
      expect(collision!.segmentIndex, 0);
      expect(collision.normal.dot(-outward), closeTo(1, 1e-6));
      expect(
        (collision.correctedPosition - point).dot(outward),
        closeTo(-(playerRadius + margin), 1e-5),
      );
    });

    test('allows passage through a destroyed segment', () {
      final point = edgePoint(0);
      final outward = outwardNormal(0);
      final destroyed = List<bool>.filled(12, false)..[0] = true;

      final collision = resolveAt(
        current: point,
        previous: point + outward * 30,
        velocity: -outward * 100,
        destroyed: destroyed,
      );

      expect(collision, isNull);
    });

    test('expels a ship from the center of the polygon', () {
      final collision = ShieldPlayerBounce.expelFromInterior(
        center: Vector2.zero(),
        outerRadius: radius,
        angleOffset: 0,
        sides: 12,
        playerPosition: Vector2.zero(),
        playerRadius: playerRadius,
        margin: margin,
      );

      expect(collision, isNotNull);
      expect(collision!.correctedPosition.length, greaterThan(radius));
      expect(
        collision.correctedPosition.distanceTo(collision.contactPoint),
        closeTo(playerRadius + margin, 1e-5),
      );
      expect(
        collision.normal.dot(outwardNormal(collision.segmentIndex)),
        closeTo(1, 1e-6),
      );
    });

    test('expels a deeply interior ship beyond the nearest polygon edge', () {
      final position = Vector2(10, -5);
      final collision = ShieldPlayerBounce.expelFromInterior(
        center: Vector2.zero(),
        outerRadius: radius,
        angleOffset: 0,
        sides: 12,
        playerPosition: position,
        playerRadius: playerRadius,
        margin: margin,
      );

      expect(collision, isNotNull);
      expect(
        (collision!.correctedPosition - collision.contactPoint).dot(
          collision.normal,
        ),
        closeTo(playerRadius + margin, 1e-5),
      );
      expect(
        collision.correctedPosition.distanceTo(Vector2.zero()),
        greaterThan(radius),
      );
    });

    test('does not expel a ship outside the polygon', () {
      final collision = ShieldPlayerBounce.expelFromInterior(
        center: Vector2.zero(),
        outerRadius: radius,
        angleOffset: 0,
        sides: 12,
        playerPosition: Vector2(0, -radius - 20),
        playerRadius: playerRadius,
        margin: margin,
      );

      expect(collision, isNull);
    });

    test(
      'reverses head-on velocity while preserving tangential glancing speed',
      () {
        final headOn = ShieldPlayerBounce.reflectVelocity(
          Vector2(0, -100),
          Vector2(0, 1),
        );
        final glancing = ShieldPlayerBounce.reflectVelocity(
          Vector2(40, -100),
          Vector2(0, 1),
        );

        expect(headOn.x, closeTo(0, 1e-6));
        expect(headOn.y, closeTo(90, 1e-6));
        expect(glancing.x, closeTo(40, 1e-6));
        expect(glancing.y, closeTo(90, 1e-6));
      },
    );

    test('detects a fast crossing using the previous position', () {
      final point = edgePoint(0);
      final outward = outwardNormal(0);
      final collision = resolveAt(
        current: point - outward * 30,
        previous: point + outward * 30,
        velocity: -outward * 500,
      );

      expect(collision, isNotNull);
      expect(collision!.normal.dot(outward), closeTo(1, 1e-6));
    });

    test(
      'solid ring pushes an overlapping ship outward from its inner side',
      () {
        final point = edgePoint(0);
        final outward = outwardNormal(0);
        final collision = resolveAt(
          current: point - outward * 5,
          previous: point - outward * 5,
          velocity: outward * 20,
          solidInnerRadius: 80,
        );

        expect(collision, isNotNull);
        expect(collision!.normal.dot(outward), closeTo(1, 1e-6));
        expect(
          (collision.correctedPosition - point).dot(outward),
          closeTo(playerRadius + margin, 1e-5),
        );
      },
    );

    test('solid ring does not affect a ship inside its inner radius', () {
      final collision = resolveAt(
        current: Vector2.zero(),
        previous: Vector2.zero(),
        velocity: Vector2(10, 0),
        solidInnerRadius: 80,
      );

      expect(collision, isNull);
    });

    test('corner contact normal points from the corner to the ship', () {
      final segmentSize = 2 * math.pi / 12;
      final corner = Vector2(
        radius * math.cos(-math.pi / 2),
        radius * math.sin(-math.pi / 2),
      );
      final outward = outwardNormal(0);
      final tangent = Vector2(
        math.cos(-math.pi / 2 + segmentSize),
        math.sin(-math.pi / 2 + segmentSize),
      );
      final current = corner + outward * 6 + tangent * 6;
      final expectedNormal = (current - corner).normalized();
      final collision = resolveAt(
        current: current,
        previous: current,
        velocity: -expectedNormal * 20,
      );

      expect(collision, isNotNull);
      expect(collision!.normal.dot(expectedNormal), closeTo(1, 1e-6));
    });

    test('does not interpret a screen wrap as a swept ring crossing', () {
      final collision = resolveAt(
        current: Vector2(-200, 0),
        previous: null,
        velocity: Vector2(-100, 0),
      );

      expect(collision, isNull);
      expect(
        ShieldPlayerBounce.isTeleport(
          previousPosition: Vector2(200, 0),
          currentPosition: Vector2(-200, 0),
          dt: 1 / 60,
          maxSpeed: 520,
          playerSize: 52,
        ),
        isTrue,
      );
    });

    test('reflects velocity relative to a moving surface', () {
      final reflected = ShieldPlayerBounce.reflectVelocity(
        Vector2(30, -120),
        Vector2(0, 1),
        surfaceVelocity: Vector2(30, -20),
      );

      expect(reflected.x, closeTo(30, 1e-6));
      expect(reflected.y, closeTo(70, 1e-6));
    });
  });
}
