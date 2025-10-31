import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A silent, short pre-home loading screen that simulates gameplay visuals:
/// - Enemy at center with rotating shield rings and a gap
/// - Enemy blast shoots toward player ship
/// - Player ship at bottom firing back
/// After [duration] elapses, [onFinished] is called so the app can show Home.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.onFinished, this.duration});
  final VoidCallback onFinished;
  final Duration? duration;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 3200),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            widget.onFinished();
          }
        });
    // Keep the animation deterministic and non-looping
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title logo on top
                  Image.asset('lib/assets/logo/cyclone_logo_title.png'),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: AnimatedBuilder(
                          animation: _ctl,
                          builder: (context, _) {
                            return _SimulatedScene(t: _ctl.value);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pure Flutter simulated gameplay panel.
class _SimulatedScene extends StatelessWidget {
  const _SimulatedScene({required this.t});
  final double t; // 0..1

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Starfield-ish background
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [Color(0xFF030303), Color(0xFF000000)],
                ),
              ),
            ),
            // Enemy with shield rings at center
            _EnemyWithShield(t: t),
            // Player ship near bottom center
            _PlayerShip(t: t),
            // Enemy blast traveling toward player
            _EnemyBlast(t: t),
            // Player bullets traveling upward
            _PlayerBullets(t: t),
          ],
        );
      },
    );
  }
}

class _EnemyWithShield extends StatelessWidget {
  const _EnemyWithShield({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, c.maxHeight) * 0.45;
        // Rotate the rings continuously; place a gap that aligns briefly
        final angle = t * 2 * math.pi;
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rings painter with a gap
                Transform.rotate(
                  angle: angle,
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _RingsPainter(),
                  ),
                ),
                // Enemy sprite in the middle
                Image.asset(
                  'lib/assets/enemy_sprite.png',
                  width: size * 0.42,
                  height: size * 0.42,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFFFFC107); // amber

    // Draw 3 rings with a small wedge gap
    for (int i = 0; i < 3; i++) {
      final radius = size.width * (0.32 + i * 0.10);
      final rect = Rect.fromCircle(center: center, radius: radius);
      const total = math.pi * 2;
      const gap = total * 0.18;
      // draw arc except the gap
      const start = -math.pi / 2; // start upwards
      // left segment
      canvas.drawArc(rect, start + gap, total - gap * 2, false, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PlayerShip extends StatelessWidget {
  const _PlayerShip({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final shipW = math.min(w, h) * 0.14;
        final x = w * 0.5 + math.sin(t * 2 * math.pi) * (w * 0.08);
        final y = h * 0.80;
        return Positioned(
          left: x - shipW / 2,
          top: y - shipW / 2,
          child: Transform.rotate(
            angle: -math.pi / 2, // point up
            child: Image.asset(
              'lib/assets/ship_sprite_moving.png',
              width: shipW,
              height: shipW,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}

class _EnemyBlast extends StatelessWidget {
  const _EnemyBlast({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final center = Offset(w / 2, h / 2);
        // travel t from center to 78% height toward player
        final pos = Offset(
          center.dx + math.sin(t * 2 * math.pi) * (w * 0.02),
          center.dy + (h * 0.28) * (t.clamp(0.0, 1.0)),
        );
        final boltSize = math.min(w, h) * 0.025;
        return Positioned(
          left: pos.dx - boltSize / 2,
          top: pos.dy - boltSize / 2,
          child: Image.asset(
            'lib/assets/enemy_blast.png',
            width: boltSize,
            height: boltSize,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}

class _PlayerBullets extends StatelessWidget {
  const _PlayerBullets({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final baseX = w * 0.5 + math.sin(t * 2 * math.pi) * (w * 0.08);
        final shipY = h * 0.80;
        final bulletH = math.min(w, h) * 0.035;
        final bulletW = bulletH * 0.22;

        Widget bullet(double offsetT, double lateral) {
          final tt = ((t + offsetT) % 1.0);
          final y = shipY - tt * (h * 0.55);
          final x = baseX + lateral;
          return Positioned(
            left: x - bulletW / 2,
            top: y - bulletH / 2,
            child: Container(
              width: bulletW,
              height: bulletH,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(bulletW),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            bullet(0.00, 0),
            bullet(0.20, -w * 0.02),
            bullet(0.40, w * 0.02),
          ],
        );
      },
    );
  }
}
