import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/components/pickups/yummy_pickup.dart';
import 'package:cyclone_game/components/hazards/mine.dart';
import 'package:cyclone_game/components/enemy/enemy_blast.dart';
import 'package:cyclone_game/components/enemy/shield_fire_solver.dart';
import 'package:cyclone_game/components/enemy/shield_player_bounce.dart';
import 'package:cyclone_game/components/enemy/shield_ring_geometry.dart';
import 'package:cyclone_game/game/cyclone_game.dart';

enum ShieldSegmentState { healthy, weakened, destroyed }

class EnemyShield extends PositionComponent with HasGameRef<CycloneGame> {
  EnemyShield({
    required this.yellowRadius,
    required this.orangeRadius,
    required this.redRadius,
    this.strokeWidth = 1,
  }) : super(size: Vector2.zero(), anchor: Anchor.center);

  final double yellowRadius;
  final double orangeRadius;
  final double redRadius;
  final double strokeWidth;

  late final ShieldRing yellowRing;
  late final ShieldRing orangeRing;
  late final ShieldRing redRing;
  double spinMultiplier = 1.0;

  List<ShieldRing> get rings => [yellowRing, orangeRing, redRing];

  Vector2? _previousPlayerPosition;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Spin speeds (radians/sec) and directions
    const double spinSpeed = math.pi / 2; // 30 deg/sec base
    yellowRing = ShieldRing(
      color: const Color(0xFFDDFF00),
      glowColor: const Color(0xFFFFFF00),
      outerRadius: yellowRadius,
      innerRadius: math.max(0, yellowRadius - 0.5),
      // Changed from strokeWidth to 2
      spinSpeed: spinSpeed,
      // clockwise (positive)
      clockwise: true,
    );
    orangeRing = ShieldRing(
      color: const Color(0xFFFFA500),
      glowColor: const Color(0xFFFFD500),
      outerRadius: orangeRadius,
      innerRadius: math.max(0, orangeRadius - 0.5),
      // Changed from strokeWidth to 2
      spinSpeed: spinSpeed * 0.9,
      clockwise: false, // counter-clockwise
    );
    redRing = ShieldRing(
      color: const Color(0xFFFF0000),
      glowColor: const Color(0xFFFF4400),
      outerRadius: redRadius,
      innerRadius: math.max(0, redRadius - 0.5),
      // Changed from strokeWidth * 1.2 to 2
      // Slightly thicker
      spinSpeed: spinSpeed * 0.8,
      clockwise: true,
    );
    for (final ring in [yellowRing, orangeRing, redRing]) {
      ring.angularVelocity =
          (ring.clockwise ? 1.0 : -1.0) * ring.spinSpeed * spinMultiplier;
    }

    // Ensure visual order: outermost red, then orange, then yellow on top
    await add(redRing);
    await add(orangeRing);
    await add(yellowRing);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Decouple shield rotation from the enemy: cancel parent's rotation so
    // rings spin only via their own angle offsets, independent of enemy facing.
    final parentComp = parent;
    if (parentComp is PositionComponent) {
      angle = -parentComp.angle;
    }
    // Slightly speed up rotation every 10 levels
    double mul = 1.0;
    if (isMounted) {
      final lvl = gameRef.gm.currentLevel.value;
      final steps = ((lvl - 1) ~/ 10).clamp(0, 1000);
      mul = (1.0 + 0.05 * steps).clamp(1.0, 1.8); // up to +80%
    }
    spinMultiplier = mul;
    for (final ring in [yellowRing, orangeRing, redRing]) {
      ring.angularVelocity =
          (ring.clockwise ? 1.0 : -1.0) * ring.spinSpeed * spinMultiplier;
      ring.updateSpin(dt);
    }
    _resolvePlayerBounce(dt);
  }

  void _resolvePlayerBounce(double dt) {
    final player = gameRef.player;
    if (!player.isMounted || !player.isAlive) {
      _previousPlayerPosition = null;
      return;
    }

    final enemy = parent;
    if (enemy is! PositionComponent) return;

    var previousPosition = _previousPlayerPosition?.clone();
    if (previousPosition != null &&
        ShieldPlayerBounce.isTeleport(
          previousPosition: previousPosition,
          currentPosition: player.position,
          dt: dt,
          maxSpeed: player.maxSpeed,
          playerSize: player.size.x,
        )) {
      previousPosition = null;
    }

    final yellowApothem =
        yellowRing.outerRadius * math.cos(math.pi / ShieldRing.sides);
    final orangeApothem =
        orangeRing.outerRadius * math.cos(math.pi / ShieldRing.sides);
    final rings = [yellowRing, orangeRing, redRing];
    for (var pass = 0; pass < 3; pass++) {
      var resolvedCollision = false;
      for (final ring in rings) {
        final solidInnerRadius = identical(ring, orangeRing)
            ? yellowApothem
            : identical(ring, redRing)
            ? orangeApothem
            : null;
        final collision = ShieldPlayerBounce.resolve(
          center: enemy.position,
          outerRadius: ring.outerRadius,
          angleOffset: ring.angleOffset,
          destroyedSegments: List.generate(
            ShieldRing.sides,
            ring.isSegmentDestroyed,
          ),
          playerPosition: player.position,
          previousPlayerPosition: previousPosition,
          playerRadius: player.size.x * 0.3,
          velocity: player.velocity,
          solidInnerRadius: solidInnerRadius,
        );
        if (collision == null) continue;

        player.position = collision.correctedPosition;
        final contactOffset = collision.contactPoint - enemy.position;
        final surfaceVelocity = Vector2(
          -ring.angularVelocity * contactOffset.y,
          ring.angularVelocity * contactOffset.x,
        );
        player.bounceOff(collision.normal, surfaceVelocity: surfaceVelocity);
        ring.flashSegment(collision.segmentIndex, duration: 0.35);
        previousPosition = player.position.clone();
        resolvedCollision = true;
      }
      if (!resolvedCollision) break;
    }
    _previousPlayerPosition = player.position.clone();
  }

  bool canFireTowardGlobal(Vector2 enemyCenter, Vector2 targetWorld) {
    return safeFireAngleTowardGlobal(
          enemyCenter,
          targetWorld,
          spawnDistance: 0,
          speed: 1e9,
          baseRadius: 0,
          growthPerSecond: 1,
          leadTime: 0,
          maxDeviation: 0,
          margin: 0,
        ) !=
        null;
  }

  /// Computes a safe world angle for an expanding blast toward [targetWorld].
  double? safeFireAngleTowardGlobal(
    Vector2 enemyCenter,
    Vector2 targetWorld, {
    required double spawnDistance,
    required double speed,
    required double baseRadius,
    required double growthPerSecond,
    required double leadTime,
    double maxDeviation = math.pi / 12,
    double margin = 2,
  }) {
    final to = targetWorld - enemyCenter;
    if (to.length2 == 0) return null;
    return ShieldFireSolver.findSafeAngle(
      rings: [yellowRing, orangeRing, redRing]
          .map(
            (ring) => ShieldRingSnapshot(
              outerRadius: ring.outerRadius,
              innerRadius: ring.innerRadius,
              angleOffset: ring.angleOffset,
              angularVelocity: ring.angularVelocity,
              destroyedSegments: List.generate(
                ShieldRing.sides,
                ring.isSegmentDestroyed,
              ),
            ),
          )
          .toList(growable: false),
      targetAngle: math.atan2(to.y, to.x),
      spawnDistance: spawnDistance,
      speed: speed,
      baseRadius: baseRadius,
      growthPerSecond: growthPerSecond,
      leadTime: leadTime,
      maxDeviation: maxDeviation,
      margin: margin,
    );
  }

  void resetAll() {
    yellowRing.resetAll();
    orangeRing.resetAll();
    redRing.resetAll();
  }
}

class ShieldRing extends PositionComponent {
  ShieldRing({
    required this.color,
    required this.glowColor,
    required this.outerRadius,
    required this.innerRadius,
    required this.spinSpeed,
    required this.clockwise,
  }) : super(size: Vector2.zero(), anchor: Anchor.center);

  static const int sides = 12;
  final Color color;
  final Color glowColor;
  final double outerRadius;
  final double innerRadius;
  final double spinSpeed; // radians/sec (magnitude)
  final bool clockwise;

  double angularVelocity = 0;

  // angleOffset rotates the ring around center over time.
  double angleOffset = 0;

  double edgeRadiusAt(double worldAngle) => ShieldRingGeometry.edgeRadiusAt(
    outerRadius: outerRadius,
    angleOffset: angleOffset,
    worldAngle: worldAngle,
    sides: sides,
  );

  final List<ShieldSegmentState> _segments = List.filled(
    sides,
    ShieldSegmentState.healthy,
  );

  // Flash timers per segment for impact feedback
  final List<double> _flashTimers = List.filled(sides, 0);
  final List<double> _flashDurations = List.filled(sides, 0.12);

  late final List<_ShieldSegmentCollider> _colliders;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _colliders = List.generate(sides, (i) => _ShieldSegmentCollider(this, i));
    for (final c in _colliders) {
      await add(c);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Decay flash timers
    for (int i = 0; i < _flashTimers.length; i++) {
      if (_flashTimers[i] > 0) {
        _flashTimers[i] = math.max(0, _flashTimers[i] - dt);
      }
    }
  }

  void updateSpin(double dt) {
    angleOffset = (angleOffset + angularVelocity * dt) % (2 * math.pi);
  }

  int segmentIndexAt(double worldAngle) => ShieldFireSolver.segmentIndexAt(
    worldAngle,
    angleOffset,
    segmentCount: sides,
  );

  bool isAngleOpen(double worldAngle) =>
      _segments[segmentIndexAt(worldAngle)] == ShieldSegmentState.destroyed;

  bool isSegmentDestroyed(int index) =>
      index >= 0 &&
      index < sides &&
      _segments[index] == ShieldSegmentState.destroyed;

  // Trigger a brief flash on the segment aligned with worldAngle
  void flashAtAngle(double worldAngle, {double duration = 0.12}) {
    flashSegment(segmentIndexAt(worldAngle), duration: duration);
  }

  void flashSegment(int index, {double duration = 0.12}) {
    if (index < 0 || index >= sides) return;
    if (_segments[index] == ShieldSegmentState.destroyed) return;
    _flashTimers[index] = duration;
    _flashDurations[index] = duration;
  }

  void hitSegment(int index) {
    final s = _segments[index];
    if (s == ShieldSegmentState.healthy) {
      _segments[index] = ShieldSegmentState.weakened;
    } else if (s == ShieldSegmentState.weakened) {
      _segments[index] = ShieldSegmentState.destroyed;
      _colliders[index].setActive(false);
      // Check full ring destroyed -> regenerate instantly
      if (_segments.every((e) => e == ShieldSegmentState.destroyed)) {
        resetAll();
      }
    }
  }

  void resetAll() {
    for (int i = 0; i < sides; i++) {
      _segments[i] = ShieldSegmentState.healthy;
      _colliders[i].setActive(true);
      _flashTimers[i] = 0;
      _flashDurations[i] = 0.12;
    }
  }

  // Rendering: draw individual edges when not destroyed.
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Precompute polygon vertices at current offset
    final double segSize = 2 * math.pi / sides;
    final List<Offset> outerVerts = List.generate(sides, (i) {
      final theta = angleOffset + (i * segSize) - math.pi / 2;
      return Offset(
        outerRadius * math.cos(theta),
        outerRadius * math.sin(theta),
      );
    });
    final List<Offset> innerVerts = List.generate(sides, (i) {
      final theta = angleOffset + (i * segSize) - math.pi / 2;
      return Offset(
        innerRadius * math.cos(theta),
        innerRadius * math.sin(theta),
      );
    });

    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    final strokeHealthy = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final strokeWeakened = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final glowWeakened = Paint()
      ..color = glowColor.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

    // Additional paints for rim highlight and inner shadow to give a subtle 3D look
    final rimHighlight = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);

    final innerShadow = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    for (int i = 0; i < sides; i++) {
      final state = _segments[i];
      if (state == ShieldSegmentState.destroyed) continue; // gap
      final int j = (i + 1) % sides;

      // Outer edge points
      final p1o = outerVerts[i];
      final p2o = outerVerts[j];
      // Inner edge points
      final p1i = innerVerts[i];
      final p2i = innerVerts[j];

      // 1) Soft translucent fill between outer and inner edges for glow and depth
      final path = Path()
        ..moveTo(p1o.dx, p1o.dy)
        ..lineTo(p2o.dx, p2o.dy)
        ..lineTo(p2i.dx, p2i.dy)
        ..lineTo(p1i.dx, p1i.dy)
        ..close();
      final mid = Offset(
        (p1o.dx + p2o.dx + p1i.dx + p2i.dx) / 4,
        (p1o.dy + p2o.dy + p1i.dy + p2i.dy) / 4,
      );
      final gradient = RadialGradient(
        colors: [
          (state == ShieldSegmentState.weakened
              ? glowColor.withOpacity(0.22)
              : glowColor.withOpacity(0.42)),
          Colors.transparent,
        ],
      );
      final fillPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: mid,
            radius: (outerRadius - innerRadius) * 2.2,
          ),
        );
      canvas.drawPath(path, fillPaint);

      // 2) Outer bloom/glow
      canvas.drawLine(
        p1o,
        p2o,
        state == ShieldSegmentState.weakened ? glowWeakened : glowPaint,
      );

      // 3) Crisp outer stroke
      canvas.drawLine(
        p1o,
        p2o,
        state == ShieldSegmentState.weakened ? strokeWeakened : strokeHealthy,
      );

      // 4) Rim highlight slightly inset for a 3D rim-light
      canvas.drawLine(p1o, p2o, rimHighlight);

      // 5) Subtle inner shadow along inner edge to fake depth
      canvas.drawLine(p1i, p2i, innerShadow);

      // 6) Flash overlay when recently impacted
      final ft = _flashTimers[i];
      if (ft > 0) {
        final alpha = (ft / _flashDurations[i]).clamp(0.0, 1.0).toDouble();
        final flashGlowPaint = Paint()
          ..color = glowColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
        final flashPaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..blendMode = BlendMode.plus;
        canvas.drawLine(p1o, p2o, flashGlowPaint);
        canvas.drawLine(p1o, p2o, flashPaint);
      }
    }
  }
}

// Collider polygon approximating a ring edge section; intercepts bullets and bounces players via parent bounce rings
class _ShieldSegmentCollider extends PositionComponent with CollisionCallbacks {
  _ShieldSegmentCollider(this.ring, this.index)
    : super(size: Vector2.zero(), anchor: Anchor.center);

  final ShieldRing ring;
  final int index;
  late PolygonHitbox _hitbox;
  bool _active = true;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildHitbox();
  }

  void _buildHitbox() {
    // Build points at current angleOffset in local coordinates (absolute units)
    _hitbox = PolygonHitbox(_quadForIndex(index, ring.angleOffset))
      ..collisionType = CollisionType.passive;
    add(_hitbox);
  }

  List<Vector2> _quadForIndex(int idx, double angleOffset) {
    final int sides = ShieldRing.sides;
    final double segSize = 2 * math.pi / sides;
    final double a1 = angleOffset + idx * segSize - math.pi / 2;
    final double a2 = angleOffset + ((idx + 1) % sides) * segSize - math.pi / 2;
    // Build quadrilateral between inner/outer radii along these two angles
    final Offset o1 = Offset(
      ring.outerRadius * math.cos(a1),
      ring.outerRadius * math.sin(a1),
    );
    final Offset o2 = Offset(
      ring.outerRadius * math.cos(a2),
      ring.outerRadius * math.sin(a2),
    );
    final Offset i1 = Offset(
      ring.innerRadius * math.cos(a1),
      ring.innerRadius * math.sin(a1),
    );
    final Offset i2 = Offset(
      ring.innerRadius * math.cos(a2),
      ring.innerRadius * math.sin(a2),
    );
    // Convert to Vector2 list in local coordinates (no normalization)
    return <Vector2>[
      Vector2(i1.dx, i1.dy),
      Vector2(i2.dx, i2.dy),
      Vector2(o2.dx, o2.dy),
      Vector2(o1.dx, o1.dy),
    ];
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Rebuild the shape to follow spin
    if (children.isNotEmpty) {
      remove(_hitbox);
    }
    _hitbox = PolygonHitbox(
      _quadForIndex(index, ring.angleOffset),
    )..collisionType = _active ? CollisionType.passive : CollisionType.inactive;
    add(_hitbox);
  }

  void setActive(bool v) {
    _active = v;
    _hitbox.collisionType = v ? CollisionType.passive : CollisionType.inactive;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (!_active) return;

    // Helper: world-space center of the enemy (EnemySprite)
    Vector2 center = Vector2.zero();
    final rp = ring.parent;
    if (rp is PositionComponent) {
      final gp = rp.parent;
      if (gp is PositionComponent) {
        center = gp.position.clone();
      }
    }

    if (other is PlayerBullet) {
      if (other.consumed) return;
      // Angle from enemy center toward the collision (use bullet position if no points)
      final impact = (intersectionPoints.isNotEmpty)
          ? intersectionPoints.first
          : other.position;
      final worldAngle = math.atan2(
        (impact.y - center.y),
        (impact.x - center.x),
      );

      // Enforce outer-to-inner gating: you cannot damage inner rings unless
      // the corresponding outer rings have an opening at the same angle.
      bool canDamage = false;
      final parentShield = rp is EnemyShield ? rp : null;
      if (parentShield != null) {
        if (identical(ring, parentShield.redRing)) {
          // Red (outermost) can always be damaged
          canDamage = true;
        } else if (identical(ring, parentShield.orangeRing)) {
          // Orange requires a hole through red at this angle
          canDamage = parentShield.redRing.isAngleOpen(worldAngle);
        } else if (identical(ring, parentShield.yellowRing)) {
          // Yellow requires holes through red and orange at this angle
          final openRed = parentShield.redRing.isAngleOpen(worldAngle);
          final openOrange = parentShield.orangeRing.isAngleOpen(worldAngle);
          canDamage = openRed && openOrange;
        }
      }

      // Consume bullet so it can't hit multiple segments this frame
      other.consumed = true;
      other.removeFromParent();

      if (canDamage) {
        // Award points only when actual damage is applied
        other.gameRef.gm.addScore(5);
        ring.hitSegment(index);
      } else {
        // Blocked: flash feedback on the impacted segment only
        ring.flashAtAngle(worldAngle);
      }
    } else if (other is EnemyBlast) {
      // Enemy blasts cannot pass through intact segments; remove them and flash.
      final impact = (intersectionPoints.isNotEmpty)
          ? intersectionPoints.first
          : other.position;
      final worldAngle = math.atan2(
        (impact.y - center.y),
        (impact.x - center.x),
      );
      ring.flashAtAngle(worldAngle, duration: 0.08);
      other.removeFromParent();
    } else if (other is YummyPickup) {
      // Destroy yummies when they touch the shield ring (no effect granted)
      if (!other.isRemoving) {
        other.removeFromParent();
      }
    } else if (other is SparkMine) {
      // Mines should ride the shield rings instead of being destroyed.
      // No action here: allow the mine to keep moving; its own logic will
      // detect proximity to ring radii and orbit until it finds an opening.
    }
  }
}
