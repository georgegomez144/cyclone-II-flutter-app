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
          // Vertical volume slider along right edge, centered vertically
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: _buildVerticalVolume(),
            ),
          ),
          Positioned(
            right: 24,
            top: isPhone ? 120 : 40,
            child: _buildExitButton(),
          ),
          Positioned(right: 24, bottom: 200, child: _buildSfxToggle()),
          Positioned(right: 24, bottom: 140, child: _buildPauseButton()),
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
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      width: 50,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up, color: Colors.amber),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
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
          const SizedBox(height: 8),
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
        ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: Colors.red.shade400.withOpacity(0.5), width: 2),
      ),
      icon: const Icon(Icons.logout),
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
