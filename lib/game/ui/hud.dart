import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:flutter/material.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay(this.game, {super.key});

  final CycloneGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
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

  @override
  Widget build(BuildContext context) {
    // Centered, unobtrusive HUD suitable for tablet/web
    return Align(
      alignment: Alignment.topLeft,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row HUD pills
                IgnorePointer(
                  ignoring: true,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      // Level
                      ValueListenableBuilder<int>(
                        valueListenable: widget.game.gm.currentLevel,
                        builder: (_, value, __) => _pill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.rocket_launch,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Level: $value',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Score (with potential multiplier later)
                      ValueListenableBuilder<int>(
                        valueListenable: widget.game.gm.score,
                        builder: (_, value, __) => _pill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Score: $value',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Lives
                      ValueListenableBuilder<int>(
                        valueListenable: widget.game.gm.lives,
                        builder: (_, value, __) => _pill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Lives: $value',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Shield progress bar
                      ValueListenableBuilder<double>(
                        valueListenable: widget.game.gm.shields,
                        builder: (_, value, __) => _pill(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 200),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shield,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 140,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      minHeight: 10,
                                      value: (value / 100).clamp(0, 1),
                                      backgroundColor: Colors.white12,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.amber,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${value.toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Colors.amber),
                                ),
                                const SizedBox(width: 10),
                                // Bullet mode indicator on the right side of the shield bar
                                ValueListenableBuilder<BulletMode>(
                                  valueListenable:
                                      widget.game.gm.currentBulletMode,
                                  builder: (context, mode, __) {
                                    IconData icon;
                                    String label;
                                    switch (mode) {
                                      case BulletMode.auto:
                                        icon = Icons.more_vert;
                                        label = 'Auto';
                                        break;
                                      case BulletMode.triple:
                                        icon = Icons.workspaces;
                                        label = 'Triple';
                                        break;
                                      case BulletMode.single:
                                      default:
                                        icon = Icons.circle;
                                        label = 'Single';
                                        break;
                                    }
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          label,
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Countdown for timed Triple+Auto power-up
                                        ValueListenableBuilder<double>(
                                          valueListenable: widget
                                              .game
                                              .gm
                                              .tripleAutoRemaining,
                                          builder: (_, seconds, __) {
                                            if (seconds <= 0)
                                              return const SizedBox.shrink();
                                            return Text(
                                              '(${seconds.ceil()}s)',
                                              style: const TextStyle(
                                                color: Colors.cyanAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        // Lock Yummy indicator
                                        ValueListenableBuilder<bool>(
                                          valueListenable:
                                              widget.game.gm.keepYummiesOnDeath,
                                          builder: (_, locked, __) {
                                            if (!locked)
                                              return const SizedBox.shrink();
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.lock,
                                                  size: 14,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Locked',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: child,
      ),
    );
  }
}
