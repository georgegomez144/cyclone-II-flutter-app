import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:flutter/material.dart';

class HudOverlay extends StatelessWidget {
  const HudOverlay(this.game, {super.key});

  final CycloneGame game;

  @override
  Widget build(BuildContext context) {
    // Centered, unobtrusive HUD suitable for tablet/web
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Score (with potential multiplier later)
                  ValueListenableBuilder<int>(
                    valueListenable: game.gm.score,
                    builder: (_, value, __) => _pill(
                      icon: Icons.star,
                      label: 'Score',
                      value: value.toString(),
                    ),
                  ),
                  // Lives
                  ValueListenableBuilder<int>(
                    valueListenable: game.gm.lives,
                    builder: (_, value, __) => _pill(
                      icon: Icons.favorite,
                      label: 'Lives',
                      value: value.toString(),
                    ),
                  ),
                  // Shield %
                  ValueListenableBuilder<double>(
                    valueListenable: game.gm.shields,
                    builder: (_, value, __) => _pill(
                      icon: Icons.shield,
                      label: 'Shield',
                      value: '${value.toStringAsFixed(0)}%'.padLeft(3, ' '),
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

  Widget _pill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Text(
              '$label: $value',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
