import 'dart:math' as math;

import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/utils.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:cyclone_game/game/audio_manager.dart';

class ControlsOverlay extends StatefulWidget {
  const ControlsOverlay({super.key, required this.game});
  final CycloneGame game;

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay> {
  bool _paused = false;

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        widget.game.pauseGame();
      } else {
        widget.game.resumeGame();
      }
    });
  }

  Offset? _joystickCenter;
  Offset? _pointerPos;

  Vector2 get _moveVector {
    if (_joystickCenter == null || _pointerPos == null) return Vector2.zero();
    final dx = _pointerPos!.dx - _joystickCenter!.dx;
    final dy = _pointerPos!.dy - _joystickCenter!.dy;
    final v = Vector2(dx, dy);
    if (v.length2 == 0) return Vector2.zero();

    // Joystick radius
    const maxR = 60.0;

    // Apply radial clamp
    final len = v.length;
    if (len > maxR) {
      v.scale(maxR / len);
    }

    // Add a deadzone and a non-linear response curve to reduce sensitivity
    const deadZone = 14.0; // pixels around center with no movement
    final r = v.length; // already clamped to [0, maxR]
    if (r <= deadZone) return Vector2.zero();

    // Normalize r ∈ (deadZone..maxR] → t ∈ (0..1]
    final tLinear = ((r - deadZone) / (maxR - deadZone)).clamp(0.0, 1.0);

    // Apply a softer curve to reduce sensitivity near center
    // Using quadratic easing: t' = t^2
    final t = tLinear * tLinear;

    // Optional overall dampening to make full push slightly less than 1
    const gain = 0.9; // 90% of full speed at max deflection

    // Direction unit vector
    final dir = v..scale(1 / (r == 0 ? 1 : r));

    // Scaled movement in [-1, 1]
    final out = Vector2(dir.x * t * gain, dir.y * t * gain);
    return out;
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

          // Right Side
          // Vertical volume slider along top left edge, under the HUD
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 12,
                top: isNarrowScreen(context) ? 180 : 140,
              ),
              child: _buildVerticalVolume(),
            ),
          ),
          // SFX Toggle
          Positioned(
            right: 24,
            bottom: isNarrowScreen(context) ? 120 : 200,
            child: _buildSfxToggle(),
          ),
          // Pause/Resume
          Positioned(
            right: 24,
            bottom: isNarrowScreen(context) ? 180 : 140,
            child: _buildPauseButton(),
          ),
          // Exit Game
          Positioned(
            right: 24,
            top: isNarrowScreen(context) ? 120 : 80,
            child: _buildExitButton(),
          ),
          // Controls cluster bottom-right: Pause/Exit above Fire button
          Positioned(right: 24, bottom: 24, child: _buildActionCluster()),
        ],
      ),
    );
  }

  Widget _buildActionCluster() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [_buildFireButton()],
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

  Widget _buildSfxToggle() {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioManager.instance.sfxEnabled,
      builder: (context, enabled, _) {
        return ElevatedButton.icon(
          onPressed: () async {
            await AudioManager.instance.setEnabled(!enabled);
            setState(() {});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.withOpacity(0.1),
            foregroundColor: Colors.blueGrey.shade200,
            elevation: 8,
            shadowColor: Colors.blueGrey.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            side: BorderSide(
              color: Colors.blueGrey.shade400.withOpacity(0.5),
              width: 2,
            ),
          ),
          icon: Icon(enabled ? Icons.volume_up : Icons.volume_off),
          label: Text(
            enabled ? 'SFX On' : 'SFX Off',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              shadows: [
                Shadow(
                  color: Colors.blueGrey.withOpacity(0.8),
                  offset: const Offset(0, 0),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalVolume() {
    final gm = widget.game.gm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      margin: EdgeInsets.only(right: 12),
      width: 55,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: AudioManager.instance.sfxEnabled,
        builder: (context, enabled, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Icon(
                enabled ? Icons.volume_up : Icons.volume_off,
                color: Colors.amber,
              ),
              SizedBox(
                height: 140,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: ValueListenableBuilder<double>(
                    valueListenable: gm.volume,
                    builder: (context, vol, _) => Slider(
                      value: vol,
                      onChanged: (v) => gm.volume.value = v,
                      activeColor: Colors.deepOrange,
                      inactiveColor: Colors.amber.shade200,
                      thumbColor: Colors.red,
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: gm.volume,
                builder: (context, vol, _) => Text(
                  '${(vol * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPauseButton() {
    return ElevatedButton.icon(
      onPressed: _togglePause,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber.withOpacity(0.1),
        foregroundColor: Colors.amber.shade200,
        elevation: 8,
        shadowColor: Colors.amber.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        side: BorderSide(
          color: Colors.amber.shade400.withOpacity(0.5),
          width: 2,
        ),
      ),
      icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
      label: Text(
        _paused ? 'Resume' : 'Pause',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(
              color: Colors.amber.withOpacity(0.8),
              offset: const Offset(0, 0),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (_paused) widget.game.resumeGame();
        widget.game.exitToHome();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.1),
        foregroundColor: Colors.red.shade200,
        elevation: 8,
        shadowColor: Colors.red.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        side: BorderSide(color: Colors.red.shade400.withOpacity(0.5), width: 2),
      ),
      icon: const Icon(Icons.close),
      label: Text(
        'Exit',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          shadows: [
            Shadow(
              color: Colors.red.withOpacity(0.8),
              offset: const Offset(0, 0),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFireButton() {
    return GestureDetector(
      onTap: () => widget.game.player.tryFire(),
      onTapDown: (_) => widget.game.player.setUiFireHeld(true),
      onTapUp: (_) => widget.game.player.setUiFireHeld(false),
      onTapCancel: () => widget.game.player.setUiFireHeld(false),
      child: Material(
        elevation: 8,
        shadowColor: Colors.redAccent.withOpacity(0.5),
        shape: const CircleBorder(),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.red.shade300,
                Colors.red.shade600,
                Colors.red.shade800,
              ],
              stops: const [0.2, 0.6, 1.0],
              center: Alignment.topLeft,
              radius: 1.2,
            ),
            border: Border.all(
              color: Colors.deepOrange.shade700.withOpacity(0.7),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.4),
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'FIRE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 32,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.6),
                  offset: const Offset(2, 2),
                  blurRadius: 2,
                ),
                Shadow(
                  color: Colors.white.withOpacity(0.4),
                  offset: const Offset(-1, -1),
                  blurRadius: 1,
                ),
              ],
            ),
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

    // Constants shared with logic above
    const maxR = 60.0;
    const deadZone = 14.0;
    const gain = 0.9;

    final c = center ?? Offset(size.width / 2, size.height / 2);

    // Base rings
    canvas.drawCircle(c, maxR, paintFill);
    canvas.drawCircle(c, maxR, paintBase);
    canvas.drawCircle(c, maxR / 2, paintBase);

    // Compute movement vector for arrow lighting
    Vector2 move = Vector2.zero();
    Offset? knobPos;
    if (pointer != null) {
      final p = pointer!;
      final dx = (p.dx - c.dx);
      final dy = (p.dy - c.dy);
      final len = math.sqrt(dx * dx + dy * dy);
      final clamped = math.min(len, maxR);
      final dirX = len == 0 ? 0.0 : dx / len;
      final dirY = len == 0 ? 0.0 : dy / len;
      final r = clamped;
      if (r > deadZone) {
        final tLinear = ((r - deadZone) / (maxR - deadZone)).clamp(0.0, 1.0);
        final t = tLinear * tLinear; // same easing as logic
        move = Vector2(dirX * t * gain, dirY * t * gain);
      }
      knobPos = Offset(c.dx + dirX * clamped, c.dy + dirY * clamped);
    }

    // Draw directional arrows (up, right, down, left)
    void drawArrow(Offset centerPoint, double angleRad, double intensity) {
      // Base styling
      final baseColor = Colors.amberAccent;
      final offColor = Colors.white24;
      final color = Color.lerp(offColor, baseColor, intensity.clamp(0.0, 1.0))!;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Arrow geometry: small isosceles triangle pointing outward
      const radius = maxR - 10; // place slightly inside ring
      const halfW = 10.0;
      const length = 16.0;

      final dir = Offset(math.cos(angleRad), math.sin(angleRad));
      final ortho = Offset(-dir.dy, dir.dx);

      final tip = centerPoint + dir * (radius + 2);
      final base = centerPoint + dir * (radius - length);
      final p1 = base + ortho * halfW;
      final p2 = base - ortho * halfW;

      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, paint);

      // Subtle glow when active
      if (intensity > 0.01) {
        final glow = Paint()
          ..color = color.withOpacity(0.35 * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(path, glow);
      }
    }

    // Compute intensities from move vector components
    final upI = (-move.y).clamp(0.0, 1.0); // y up is negative
    final downI = (move.y).clamp(0.0, 1.0);
    final leftI = (-move.x).clamp(0.0, 1.0);
    final rightI = (move.x).clamp(0.0, 1.0);

    // Angles: 0 = right, pi/2 = down (screen coords), pi = left, -pi/2 = up
    drawArrow(c, -math.pi / 2, upI); // up
    drawArrow(c, 0.0, rightI); // right
    drawArrow(c, math.pi / 2, downI); // down
    drawArrow(c, math.pi, leftI); // left

    // Draw knob last (on top)
    if (knobPos != null) {
      final knob = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      canvas.drawCircle(knobPos, 18, knob);
    }
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.pointer != pointer;
  }
}
