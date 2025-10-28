import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:cyclone_game/components/player/player_bullet.dart';
import 'package:cyclone_game/components/player/player.dart';

enum ShieldSegmentState { healthy, weakened, destroyed }

class EnemyShield extends PositionComponent {
  EnemyShield({
    required this.yellowRadius,
    required this.orangeRadius,
    required this.redRadius,
    this.strokeWidth = 4,
  }) : super(size: Vector2.zero(), anchor: Anchor.center);

  final double yellowRadius;
  final double orangeRadius;
  final double redRadius;
  final double strokeWidth;

  late final ShieldRing yellowRing;
  late final ShieldRing orangeRing;
  late final ShieldRing redRing;

  // Bounce rings that always repel the player, even if a segment is destroyed.
  late final _ShieldBounceRing _yellowBounce;
  late final _ShieldBounceRing _orangeBounce;
  late final _ShieldBounceRing _redBounce;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Spin speeds (radians/sec) and directions
    const double spinSpeed = math.pi / 6; // 30 deg/sec base
    yellowRing = ShieldRing(
      color: const Color(0xFFFFFF00),
      glowColor: const Color(0xFFFFFF00),
      outerRadius: yellowRadius,
      innerRadius: math.max(0, yellowRadius - strokeWidth),
      spinSpeed: spinSpeed, // clockwise (positive)
      clockwise: true,
    );
    orangeRing = ShieldRing(
      color: const Color(0xFFFFA500),
      glowColor: const Color(0xFFFFA500),
      outerRadius: orangeRadius,
      innerRadius: math.max(0, orangeRadius - strokeWidth),
      spinSpeed: spinSpeed * 0.9,
      clockwise: false, // counter-clockwise
    );
    redRing = ShieldRing(
      color: const Color(0xFFFF0000),
      glowColor: const Color(0xFFFF0000),
      outerRadius: redRadius,
      innerRadius: math.max(0, redRadius - strokeWidth),
      spinSpeed: spinSpeed * 0.8,
      clockwise: true,
    );

    // Ensure visual order: outermost red, then orange, then yellow on top
    await add(redRing);
    await add(orangeRing);
    await add(yellowRing);

    // Bounce rings for the player
    _redBounce = _ShieldBounceRing(radius: redRadius + strokeWidth * 0.5);
    _orangeBounce = _ShieldBounceRing(radius: orangeRadius + strokeWidth * 0.5);
    _yellowBounce = _ShieldBounceRing(radius: yellowRadius + strokeWidth * 0.5);
    await add(_redBounce);
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

  late final List<_ShieldSegmentCollider> _colliders;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _colliders = List.generate(sides, (i) => _ShieldSegmentCollider(this, i));
    for (final c in _colliders) {
      await add(c);
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

    for (int i = 0; i < sides; i++) {
      final state = _segments[i];
      if (state == ShieldSegmentState.destroyed) continue; // gap
      final int j = (i + 1) % sides;
      // draw as two parallel lines blended: outer and inner, but simpler: single line at outer radius
      final p1 = outerVerts[i];
      final p2 = outerVerts[j];
      // Glow first
      canvas.drawLine(
        p1,
        p2,
        state == ShieldSegmentState.weakened ? glowWeakened : glowPaint,
      );
      // Then crisp stroke
      canvas.drawLine(
        p1,
        p2,
        state == ShieldSegmentState.weakened ? strokeWeakened : strokeHealthy,
      );
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
    if (other is PlayerBullet) {
      if (other.consumed) return;
      // Consume the bullet and apply damage on the first segment it touches
      other.consumed = true;
      other.removeFromParent();
      ring.hitSegment(index);
    }
  }
}

class _ShieldBounceRing extends PositionComponent with CollisionCallbacks {
  _ShieldBounceRing({required this.radius})
    : super(size: Vector2.all(1), anchor: Anchor.center);

  final double radius;
  late final CircleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = CircleHitbox.relative(1, parentSize: Vector2.all(2 * radius))
      ..collisionType = CollisionType.passive;
    add(_hitbox);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Player) {
      // Push player outward to the ring boundary + small epsilon
      final Vector2 center = absolutePosition; // world center
      final Vector2 toPlayer = other.position - center;
      if (toPlayer.length2 == 0) return;
      final dir = toPlayer.normalized();
      final double desiredDist = radius + 8; // epsilon
      other.position = center + dir * desiredDist;
    }
  }
}
