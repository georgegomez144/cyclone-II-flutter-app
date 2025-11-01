import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable, centered "How to Play" content with animated sprites
/// showcasing gameplay, hazards, and pickups.
class HowToPlayContent extends StatelessWidget {
  const HowToPlayContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _Section(
          title: 'Goal',
          children: [
            Text(
              'Create openings in the rotating enemy shield and blast the enemy core to clear the level. Stay alive by avoiding enemy fire and mines while collecting helpful yummies.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber, height: 1.35),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Section(
          title: 'Controls',
          children: [
            Text(
              '• Move: on-screen joystick (bottom-left)\n• Fire: big red FIRE button (bottom-right)\n• Bullets fire from the ship\'s nose. Aim your ship to shoot through gaps.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber, height: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Section(
          title: 'Enemy Ship & Shield',
          children: [
            _SpriteRow(
              label: 'Enemy Core & Shield',
              assetPath: 'lib/assets/enemy_sprite.png',
              description:
                  'The core is protected by a rotating multi-ring shield. Shoot sections to make gaps, then hit the core to win.',
              animate: _Anim.rotate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Section(
          title: 'Your Ship & Hazards',
          children: [
            _SpriteRow(
              label: 'Player Ship',
              assetPath: 'lib/assets/ship_sprite_moving.png',
              description:
                  'You. Stay mobile, weave through threats, and line up shots on the enemy shield/core.',
              animate: _Anim.rotate,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Enemy Blast',
              assetPath: 'lib/assets/enemy_blast.png',
              description:
                  'Glowing bolts launched by the enemy. Getting hit costs a life. Keep moving!',
              animate: _Anim.pulse,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Spark Mine',
              assetPath: 'lib/assets/spark_mine_sprite.png',
              description:
                  'Drifts and can home in. On contact: heavy shield damage or death if shields are gone.',
              animate: _Anim.wiggle,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Section(
          title: 'Yummies (Pickups)',
          children: [
            _SpriteRow(
              label: 'Shield +1',
              assetPath: 'lib/assets/yummy_sprite.png',
              colorTint: Color(0xFFEFFF57),
              description:
                  'Grants a one-hit shield that blocks the next enemy blast.',
              animate: _Anim.pulse,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Points',
              assetPath: 'lib/assets/yummy_sprite.png',
              colorTint: Colors.white,
              description: 'Score boost. Collect to climb the leaderboard.',
              animate: _Anim.rotate,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Extra Life',
              assetPath: 'lib/assets/yummy_sprite.png',
              colorTint: Color(0xFF69F0AE),
              description: 'Grants an additional life.',
              animate: _Anim.wiggle,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Continuous Fire',
              assetPath: 'lib/assets/yummy_sprite.png',
              colorTint: Color(0xFFFF5252),
              description:
                  'Hold the FIRE button to auto-fire a stream of bullets for a short time.',
              animate: _Anim.pulse,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Triple Spread',
              assetPath: 'lib/assets/yummy_sprite.png',
              colorTint: Color(0xFF64B5F6),
              description:
                  'Temporarily fires 3 bullets in a spread. Great for carving shield gaps.',
              animate: _Anim.rotate,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Triple Auto (Timed)',
              assetPath: 'lib/assets/yummy_sprite.png',
              colorTint: Color(0xFF00E5FF),
              description:
                  'Combines Triple Spread with continuous auto‑fire for a limited time. Reverts when the timer ends.',
              animate: _Anim.rotate,
            ),
            SizedBox(height: 10),
            _SpriteRow(
              label: 'Lock',
              assetPath: 'lib/assets/yummy_sprite.png',
              colorTint: Color(0xFFBDBDBD),
              description:
                  'Locks in your current yummies so you keep them after losing a life (one-time protection).',
              animate: _Anim.wiggle,
            ),
            SizedBox(height: 6),
            Text(
              'Tip: Yummies pop out when you destroy shield sections or damage the enemy core.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.amber,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Section(
          title: 'Scoring & Progress',
          children: [
            Text(
              'Earn points for destroying shield sections, mines, and hitting the core. Clear the level by destroying the core; later levels spawn threats faster.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber, height: 1.35),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

enum _Anim { rotate, pulse, wiggle }

class _SpriteRow extends StatelessWidget {
  const _SpriteRow({
    required this.label,
    required this.assetPath,
    required this.description,
    this.animate = _Anim.pulse,
    this.colorTint,
  });

  final String label;
  final String assetPath;
  final String description;
  final _Anim animate;
  final Color? colorTint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AnimatedSprite(
          assetPath: assetPath,
          size: 44,
          animate: animate,
          colorTint: colorTint,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(color: Colors.amber)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedSprite extends StatefulWidget {
  const _AnimatedSprite({
    required this.assetPath,
    required this.size,
    required this.animate,
    this.colorTint,
  });
  final String assetPath;
  final double size;
  final _Anim animate;
  final Color? colorTint;

  @override
  State<_AnimatedSprite> createState() => _AnimatedSpriteState();
}

class _AnimatedSpriteState extends State<_AnimatedSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, child) {
        final t = _ctl.value;
        double angle = 0;
        double scale = 1;
        Offset offset = Offset.zero;
        switch (widget.animate) {
          case _Anim.rotate:
            angle = t * 2 * math.pi;
            break;
          case _Anim.pulse:
            scale = 0.9 + 0.1 * math.sin(t * 2 * math.pi);
            break;
          case _Anim.wiggle:
            angle = 0.15 * math.sin(t * 2 * math.pi);
            offset = Offset(2 * math.sin(t * 2 * math.pi), 0);
            break;
        }
        Widget img = Image.asset(
          widget.assetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          color: widget.colorTint,
          colorBlendMode: widget.colorTint == null
              ? BlendMode.srcIn
              : BlendMode.modulate,
        );
        img = Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: img),
          ),
        );
        return img;
      },
    );
  }
}
