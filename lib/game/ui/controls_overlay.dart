import 'dart:math' as math;

import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

class ControlsOverlay extends StatefulWidget {
  const ControlsOverlay({super.key, required this.game});
  final CycloneGame game;

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay> {
  Offset? _joystickCenter;
  Offset? _pointerPos;

  Vector2 get _moveVector {
    if (_joystickCenter == null || _pointerPos == null) return Vector2.zero();
    final dx = _pointerPos!.dx - _joystickCenter!.dx;
    final dy = _pointerPos!.dy - _joystickCenter!.dy;
    final v = Vector2(dx, dy);
    if (v.length2 == 0) return Vector2.zero();
    final maxR = 60.0;
    if (v.length > maxR) {
      v.scale(maxR / v.length);
    }
    // Normalize to [-1,1]
    final norm = Vector2(v.x / maxR, v.y / maxR);
    return norm;
  }

  void _updatePlayerMove() {
    widget.game.player.setMoveFromJoystick(_moveVector);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          // Joystick bottom-left
          Positioned(left: 16, bottom: 16, child: _buildJoystick()),
          // Fire button bottom-right
          Positioned(right: 24, bottom: 24, child: _buildFireButton()),
        ],
      ),
    );
  }

  Widget _buildJoystick() {
    return GestureDetector(
      onPanStart: (d) {
        setState(() {
          _joystickCenter = d.localPosition;
          _pointerPos = d.localPosition;
          _updatePlayerMove();
        });
      },
      onPanUpdate: (d) {
        setState(() {
          _pointerPos = d.localPosition;
          _joystickCenter ??= d.localPosition;
          _updatePlayerMove();
        });
      },
      onPanEnd: (_) {
        setState(() {
          _pointerPos = null;
          _joystickCenter = null;
          _updatePlayerMove();
        });
      },
      child: CustomPaint(
        painter: _JoystickPainter(
          center: _joystickCenter,
          pointer: _pointerPos,
        ),
        size: const Size(160, 160),
      ),
    );
  }

  Widget _buildFireButton() {
    return GestureDetector(
      onTapDown: (_) => widget.game.player.tryFireBurst(),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.redAccent, blurRadius: 8, spreadRadius: 2),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'FIRE',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({this.center, this.pointer});
  final Offset? center;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final paintFill = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.fill;

    final c = center ?? Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 60, paintFill);
    canvas.drawCircle(c, 60, paintBase);
    canvas.drawCircle(c, 30, paintBase);

    if (pointer != null) {
      final p = pointer!;
      final knob = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill;
      final dx = (p.dx - c.dx);
      final dy = (p.dy - c.dy);
      final len = math.sqrt(dx * dx + dy * dy);
      final maxR = 60.0;
      final kx = c.dx + (len == 0 ? 0 : dx * (math.min(len, maxR) / len));
      final ky = c.dy + (len == 0 ? 0 : dy * (math.min(len, maxR) / len));
      canvas.drawCircle(Offset(kx, ky), 18, knob);
    }
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.pointer != pointer;
  }
}
