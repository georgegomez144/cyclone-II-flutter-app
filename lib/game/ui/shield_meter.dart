import 'package:cyclone_game/game/game_manager.dart';
import 'package:flutter/material.dart';

class ShieldMeter extends StatelessWidget {
  const ShieldMeter({required this.gameManager, super.key});

  final GameManager gameManager;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: gameManager.playerShield,
      builder: (context, playerShield, _) => ValueListenableBuilder<double>(
        valueListenable: gameManager.shields,
        builder: (context, shipShields, _) {
          final hasPlayerShield = playerShield > 0;
          final value = hasPlayerShield ? playerShield : shipShields;
          final color = hasPlayerShield ? Colors.lightBlueAccent : Colors.amber;

          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: color, size: 16),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: (value / 100).clamp(0, 1),
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${value.toStringAsFixed(0)}%',
                  style: TextStyle(color: color),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
