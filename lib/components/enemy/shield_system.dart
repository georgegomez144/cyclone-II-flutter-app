import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/components/player/player.dart';
import 'package:cyclone_game/components/pickups/yummy_pickup.dart';
import 'package:cyclone_game/components/hazards/mine.dart';
import 'package:cyclone_game/components/effects/electric_shield.dart';
import 'package:cyclone_game/components/enemy/enemy_blast.dart';

enum ShieldSegmentState { healthy, weakened, destroyed }

class EnemyShield extends PositionComponent {
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

  // Bounce ring that repels the player (outer red ring only).
  late final _ShieldBounceRing _yellowBounce;
  late final _ShieldBounceRing _orangeBounce;
  late final _ShieldBounceRing _redBounce;

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

    // Ensure visual order: outermost red, then orange, then yellow on top
    await add(redRing);
    await add(orangeRing);
    await add(yellowRing);

    // Bounce rings: repel the player at each outer ring edge and connect to visual ring for flash feedback
    _yellowBounce = _ShieldBounceRing(
      radius: yellowRadius + strokeWidth * 0.8,
      ring: yellowRing,
    );
    _orangeBounce = _ShieldBounceRing(
      radius: orangeRadius + strokeWidth * 0.8,
      ring: orangeRing,
    );
    _redBounce = _ShieldBounceRing(
      radius: redRadius + strokeWidth * 0.8,
      ring: redRing,
    );
    await add(_redBounce); // outermost on bottom
    await add(_orangeBounce);
    await add(_yellowBounce);
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
    yellowRing.updateSpin(dt);
    orangeRing.updateSpin(dt);
    redRing.updateSpin(dt);
  }

  bool canFireTowardGlobal(Vector2 enemyCenter, Vector2 targetWorld) {
    final dir = targetWorld - enemyCenter;
    if (dir.length2 == 0) return false;
    final angle = math.atan2(dir.y, dir.x); // -pi..pi
    return yellowRing.isAngleOpen(angle) &&
        orangeRing.isAngleOpen(angle) &&
        redRing.isAngleOpen(angle);
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

  // angleOffset rotates the ring around center over time.
  double angleOffset = 0;

  final List<ShieldSegmentState> _segments = List.filled(
    sides,
    ShieldSegmentState.healthy,
  );

  // Flash timers per segment for impact feedback
  final List<double> _flashTimers = List.filled(sides, 0);

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
    final dir = clockwise ? 1.0 : -1.0;
    angleOffset = (angleOffset + dir * spinSpeed * dt) % (2 * math.pi);
  }

  bool isAngleOpen(double worldAngle) {
    // Convert worldAngle to ring-local segment index using angleOffset
    double a = worldAngle - angleOffset; // rotate opposite to offset
    // normalize to 0..2pi
    while (a < 0) a += 2 * math.pi;
    while (a >= 2 * math.pi) a -= 2 * math.pi;
    final double segSize = 2 * math.pi / sides;
    final int idx = (a ~/ segSize) % sides;
    return _segments[idx] == ShieldSegmentState.destroyed;
  }

  // Trigger a brief flash on the segment aligned with worldAngle
  void flashAtAngle(double worldAngle, {double duration = 0.12}) {
    double a = worldAngle - angleOffset;
    while (a < 0) a += 2 * math.pi;
    while (a >= 2 * math.pi) a -= 2 * math.pi;
    final double segSize = 2 * math.pi / sides;
    final int idx = (a ~/ segSize) % sides;
    flashSegment(idx, duration: duration);
  }

  void flashSegment(int index, {double duration = 0.12}) {
    if (index < 0 || index >= sides) return;
    if (_segments[index] == ShieldSegmentState.destroyed) return;
    _flashTimers[index] = duration;
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
        final alpha = (ft.clamp(0.0, 0.12) as double) / 0.12; // fade
        final flashPaint = Paint()
          ..color = Colors.white.withOpacity(0.9 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..blendMode = BlendMode.plus;
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

class _ShieldBounceRing extends PositionComponent with CollisionCallbacks {
  _ShieldBounceRing({required this.radius, required this.ring})
    : super(size: Vector2.zero(), anchor: Anchor.center);

  final double radius;
  final ShieldRing ring;
  late final CircleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Ensure this component has a size that matches the intended diameter
    size = Vector2.all(2 * radius);
    // Activate collision so the ring acts as a solid barrier for the player
    _hitbox = CircleHitbox.relative(0.5, parentSize: size)
      ..collisionType = CollisionType.active;
    add(_hitbox);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    _repelIfPlayer(other);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    _repelIfPlayer(other);
  }

  void _repelIfPlayer(PositionComponent other) {
    // Keep only player outside of the bounce radius; other entities unaffected here.
    if (other is! Player) return;
    // Compute world-space center by walking up two levels: EnemyShield -> EnemySprite
    Vector2 center = Vector2.zero();
    final p = parent;
    if (p is PositionComponent) {
      final gp = p.parent;
      if (gp is PositionComponent) {
        center = gp.position.clone();
      }
    }
    // If center is zero (fallback), do nothing to avoid snapping to origin.
    if (center == Vector2.zero()) return;

    final toPlayer = other.position - center;
    double dist = toPlayer.length;
    if (dist == 0) {
      // Nudge in a random outward direction if exactly centered
      dist = 0.0001;
    }
    final dir = toPlayer.length2 == 0
        ? Vector2(1, 0)
        : toPlayer / dist; // outward normal

    // Desired minimal distance from center: ring radius plus a small margin and player's radius
    final playerRadius = other.size.length / 4; // approx
    final margin = 2.0;
    final minDist = radius + playerRadius + margin;
    if (dist < minDist) {
      // Clamp player to the ring boundary just outside
      other.position = center + dir * minDist;

      // Head-on detection and player turnaround
      other.handleShieldImpact(dir);

      // Flash the ring segment at the impact angle
      final impactAngle = math.atan2(dir.y, dir.x);
      ring.flashAtAngle(impactAngle);
    }
  }
}
