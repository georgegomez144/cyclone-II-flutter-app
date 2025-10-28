import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// CycloneGame: the root Flame game for Cyclone II.
/// For now it only clears the screen to black.
class CycloneGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF000000);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GameWidget(game: CycloneGame()));
}
