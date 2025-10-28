import 'dart:math' as math;

import 'package:cyclone_game/components/enemy/shield_section.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum RingIndex { inner, middle, outer }

class ShieldRing extends PositionComponent {
  ShieldRing({
    required this.index,
    required this.radiusInner,
    required this.radiusOuter,
    required this.color,
  }) : super(anchor: Anchor.center);

  final RingIndex index;
  final double radiusInner;
  final double radiusOuter;
  final Color color;

  // Angular speed in radians/sec (set by EnemyCore on creation)
  double angularSpeed = 0;

  final List<ShieldSection> sections = [];
  static const int segments = 12; // dodecagon

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(radiusOuter * 2);
    _buildSections();
  }

  void _buildSections() {
    sections.clear();
    final delta = 2 * math.pi / segments;
    for (int i = 0; i < segments; i++) {
      final start = i * delta;
      final end = (i + 1) * delta;
      final sec = ShieldSection(
        radiusInner: radiusInner,
        radiusOuter: radiusOuter,
        angleStart: start,
        angleEnd: end,
        color: color,
      );
      sections.add(sec);
    }
    addAll(sections);
  }

  /// Regenerate all destroyed sections back to full.
  void regenerate() {
    for (final s in sections) {
      s.regenerate();
    }
  }

  /// Call each update to check if the entire ring is destroyed.
  @override
  void update(double dt) {
    super.update(dt);

    // Spin the ring
    if (angularSpeed != 0) {
      angle += angularSpeed * dt;
    }

    if (sections.isNotEmpty && sections.every((s) => s.isDestroyed)) {
      // Regenerate the ring when completely destroyed
      regenerate();
    }
  }

  /// Returns true if at the given global angle (radians, 0 along +X),
  /// the ray from center lies within a destroyed section (gap) of this ring.
  bool isOpenAtAngle(double angle) {
    // normalize 0..2pi and account for ring's current rotation (component angle)
    final twoPi = 2 * math.pi;
    var a = (angle - this.angle) % twoPi; // convert to ring local space
    if (a < 0) a += twoPi;
    final delta = twoPi / segments;
    final idx = (a / delta).floor().clamp(0, segments - 1);
    final sec = sections[idx];
    return sec.isDestroyed;
  }
}
