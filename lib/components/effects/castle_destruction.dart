import 'dart:math' as math;

import 'package:cyclone_game/components/effects/castle_explosion.dart';
import 'package:cyclone_game/components/effects/castle_ring_piece.dart';
import 'package:cyclone_game/components/effects/explosion.dart';
import 'package:cyclone_game/components/effects/shield_segment_sparks.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CastleDestruction extends PositionComponent {
  CastleDestruction({
    required List<CastleRingSnapshot> rings,
    required this.shipSprite,
    required Vector2 shipSize,
    required this.shipAngle,
    required this.maxRadius,
    this.onShipExploded,
    this.segmentPhase = 1.8,
    this.pieceFlightDuration = 0.45,
    math.Random? random,
  }) : rings = List<CastleRingSnapshot>.unmodifiable(rings),
       shipSize = shipSize.clone(),
       _random = random ?? math.Random(),
       super(size: Vector2.zero(), anchor: Anchor.center) {
    assert(segmentPhase > 0);
    assert(pieceFlightDuration > 0);
    _createPieces();
  }

  static const double _shipAfterPiecesDelay = 0.25;
  static const double _emptyShieldDelay = 0.65;
  static const double _shipPopInterval = 0.22;

  final List<CastleRingSnapshot> rings;
  final Sprite? shipSprite;
  final Vector2 shipSize;
  final double shipAngle;
  final double maxRadius;
  final VoidCallback? onShipExploded;
  final double segmentPhase;
  final double pieceFlightDuration;
  final math.Random _random;
  final List<CastleRingPiece> _pieces = [];

  double _elapsed = 0;
  double _nextShipPopAt = 0.12;
  int _explodedPieceCount = 0;
  bool _isShipDestroyed = false;
  bool _callbackFired = false;
  bool _isFinished = false;

  int get pieceCount => _pieces.length;
  int get explodedPieceCount => _explodedPieceCount;
  bool get isShipDestroyed => _isShipDestroyed;
  bool get isFinished => _isFinished;

  double get _pieceInterval =>
      _pieces.isEmpty ? 0 : segmentPhase / _pieces.length;

  double get _shipExplosionAt => _pieces.isEmpty
      ? _emptyShieldDelay
      : _pieceInterval * (_pieces.length - 1) + _shipAfterPiecesDelay;

  void _createPieces() {
    for (final ring in rings) {
      if (ring.destroyedSegments.isEmpty) continue;
      final startIndex = _random.nextInt(ring.destroyedSegments.length);
      for (var offset = 0; offset < ring.destroyedSegments.length; offset++) {
        final index = (startIndex + offset) % ring.destroyedSegments.length;
        if (!ring.destroyedSegments[index]) {
          _pieces.add(CastleRingPiece(ring: ring, segmentIndex: index));
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt < 0 || _isFinished) return;

    _elapsed += dt;
    while (_explodedPieceCount < _pieces.length &&
        _elapsed >= _explodedPieceCount * _pieceInterval) {
      _detachPiece(_pieces[_explodedPieceCount]);
      _explodedPieceCount++;
    }

    while (!_isShipDestroyed && _elapsed >= _nextShipPopAt) {
      _emitShipPop();
      _nextShipPopAt += _shipPopInterval;
    }

    if (!_isShipDestroyed && _elapsed >= _shipExplosionAt) {
      _explodeShip();
    }

    if (_isShipDestroyed &&
        _explodedPieceCount == _pieces.length &&
        _pieces.every(
          (piece) => _elapsed - piece.detachedAt! >= pieceFlightDuration,
        )) {
      _isFinished = true;
      if (isMounted) removeFromParent();
    }
  }

  void _detachPiece(CastleRingPiece piece) {
    final ring = piece.ring;
    final segmentSize = 2 * math.pi / ring.destroyedSegments.length;
    final startAngle =
        ring.angleOffset + piece.segmentIndex * segmentSize - math.pi / 2;
    piece.detachedAt = _elapsed;
    piece.detachedAngle = startAngle + ring.angularVelocity * _elapsed;
    piece.directionAngle = piece.detachedAngle + segmentSize / 2;

    final start = _pointAt(ring.outerRadius, piece.detachedAngle);
    final end = _pointAt(ring.outerRadius, piece.detachedAngle + segmentSize);
    final parentComponent = parent;
    if (parentComponent != null) {
      parentComponent.add(
        ShieldSegmentSparks(start: start, end: end, glowColor: ring.glowColor)
          ..position = position.clone()
          ..priority = priority + 1,
      );
    }
  }

  void _emitShipPop() {
    final parentComponent = parent;
    if (parentComponent == null) return;

    final angle = _random.nextDouble() * 2 * math.pi;
    final radius = shipSize.x * (0.12 + _random.nextDouble() * 0.25);
    parentComponent.add(
      Explosion(
          duration: 0.28,
          maxRadius: 8 + _random.nextDouble() * 7,
          color: _random.nextBool() ? Colors.orangeAccent : Colors.deepOrange,
        )
        ..position =
            position.clone() +
            Vector2(math.cos(angle), math.sin(angle)) * radius
        ..priority = priority + 1,
    );
  }

  void _explodeShip() {
    _isShipDestroyed = true;
    final parentComponent = parent;
    if (parentComponent != null) {
      parentComponent.add(
        CastleExplosion(maxRadius: maxRadius, duration: 0.9)
          ..position = position.clone()
          ..priority = priority + 1,
      );
    }
    if (!_callbackFired) {
      _callbackFired = true;
      onShipExploded?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    for (final piece in _pieces) {
      if (piece.detachedAt == null) {
        _renderIntactPiece(canvas, piece);
      } else {
        _renderFlyingPiece(canvas, piece);
      }
    }
    if (!_isShipDestroyed) _renderShip(canvas);
  }

  void _renderIntactPiece(Canvas canvas, CastleRingPiece piece) {
    final ring = piece.ring;
    final segmentSize = 2 * math.pi / ring.destroyedSegments.length;
    final startAngle =
        ring.angleOffset +
        piece.segmentIndex * segmentSize -
        math.pi / 2 +
        ring.angularVelocity * _elapsed;
    _drawPiece(
      canvas,
      ring: ring,
      startAngle: startAngle,
      segmentSize: segmentSize,
      alpha: 1,
    );
  }

  void _renderFlyingPiece(Canvas canvas, CastleRingPiece piece) {
    final progress = ((_elapsed - piece.detachedAt!) / pieceFlightDuration)
        .clamp(0.0, 1.0)
        .toDouble();
    if (progress >= 1) return;

    final ring = piece.ring;
    final segmentSize = 2 * math.pi / ring.destroyedSegments.length;
    final distance = 12 + maxRadius * 0.55 * progress;
    final direction = Vector2(
      math.cos(piece.directionAngle),
      math.sin(piece.directionAngle),
    );
    canvas.save();
    canvas.translate(direction.x * distance, direction.y * distance);
    canvas.rotate(progress * 5);
    _drawPiece(
      canvas,
      ring: ring,
      startAngle: piece.detachedAngle,
      segmentSize: segmentSize,
      alpha: 1 - progress,
    );
    canvas.restore();
  }

  void _drawPiece(
    Canvas canvas, {
    required CastleRingSnapshot ring,
    required double startAngle,
    required double segmentSize,
    required double alpha,
  }) {
    final outerStart = _pointAt(ring.outerRadius, startAngle).toOffset();
    final outerEnd = _pointAt(
      ring.outerRadius,
      startAngle + segmentSize,
    ).toOffset();
    final innerRadius = math.max(0, ring.outerRadius - 4).toDouble();
    final innerStart = _pointAt(innerRadius, startAngle).toOffset();
    final innerEnd = _pointAt(innerRadius, startAngle + segmentSize).toOffset();
    final path = Path()
      ..moveTo(outerStart.dx, outerStart.dy)
      ..lineTo(outerEnd.dx, outerEnd.dy)
      ..lineTo(innerEnd.dx, innerEnd.dy)
      ..lineTo(innerStart.dx, innerStart.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = ring.glowColor.withValues(alpha: 0.42 * alpha),
    );
    canvas.drawLine(
      outerStart,
      outerEnd,
      Paint()
        ..color = ring.glowColor.withValues(alpha: 0.9 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
    );
    canvas.drawLine(
      outerStart,
      outerEnd,
      Paint()
        ..color = ring.color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      innerStart,
      innerEnd,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _renderShip(Canvas canvas) {
    final progress = (_elapsed / _shipExplosionAt).clamp(0.0, 1.0).toDouble();
    final shake = 1.5 + 2.5 * progress;
    final offset = Vector2(
      math.sin(_elapsed * 39) * shake,
      math.cos(_elapsed * 33) * shake,
    );
    final flicker = (0.68 + 0.32 * math.sin(_elapsed * 28)).clamp(0.25, 1.0);
    final tint = (0.15 + 0.65 * progress).clamp(0.0, 0.8);

    canvas.save();
    canvas.translate(offset.x, offset.y);
    canvas.rotate(shipAngle);
    final sprite = shipSprite;
    if (sprite != null) {
      sprite.render(
        canvas,
        position: Vector2(-shipSize.x / 2, -shipSize.y / 2),
        size: shipSize,
        overridePaint: Paint()
          ..color = Colors.white.withValues(alpha: flicker)
          ..colorFilter = ColorFilter.mode(
            Color.lerp(Colors.white, const Color(0xFFFF4E18), tint)!,
            BlendMode.modulate,
          ),
      );
    } else {
      final path = Path()
        ..moveTo(0, -shipSize.y / 2)
        ..lineTo(shipSize.x * 0.38, shipSize.y / 2)
        ..lineTo(0, shipSize.y * 0.28)
        ..lineTo(-shipSize.x * 0.38, shipSize.y / 2)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFF4E18).withValues(alpha: flicker)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.restore();
  }

  Vector2 _pointAt(double radius, double angle) =>
      Vector2(radius * math.cos(angle), radius * math.sin(angle));
}
