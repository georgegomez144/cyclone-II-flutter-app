import 'package:flutter/material.dart';

class InstructionsOverlay extends StatelessWidget {
  const InstructionsOverlay({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Instructions',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Move your ship with the on-screen joystick (bottom-left) or with WASD/Arrow keys on desktop.\n\nTap the red FIRE button (bottom-right) or press Space/Ctrl to shoot up to three inline bullets from the ship\'s nose.\n\nThread shots through gaps to hit the enemy core (coming soon). Avoid hazards and manage your shields.\n\nAll text is amber on black, buttons are red for high visibility.',
                    style: TextStyle(color: Colors.amber, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Back to Home'),
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
