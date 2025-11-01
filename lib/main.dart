import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/ui/hud.dart';
import 'package:cyclone_game/game/ui/home_menu.dart';
import 'package:cyclone_game/game/ui/controls_overlay.dart';
import 'package:cyclone_game/game/ui/instructions.dart';
// Removed LoadingScreen; startup demo runs inside CycloneGame
import 'package:cyclone_game/game/audio_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize audio manager and preload SFX
  await AudioManager.instance.init();
  runApp(const CycloneRootApp());
}

class CycloneRootApp extends StatefulWidget {
  const CycloneRootApp({super.key});

  @override
  State<CycloneRootApp> createState() => _CycloneRootAppState();
}

class _CycloneRootAppState extends State<CycloneRootApp> {
  bool _loadingDone = false;
  late final CycloneGame _game;

  @override
  void initState() {
    super.initState();
    _game = CycloneGame();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Aldrich',
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Colors.amber,
        secondary: Colors.red,
        surface: Colors.black,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Colors.red,
        inactiveTrackColor: Color(0xFFEFB7B7),
        thumbColor: Colors.red,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.black,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.amber),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        hintStyle: TextStyle(color: Colors.amber),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Aldrich',
        ).textTheme.apply(bodyColor: Colors.amber),
      ),
      home: Scaffold(
        body: GameWidget(
          game: _game,
          overlayBuilderMap: {
            'home': (context, game) => HomeMenu(game: game as CycloneGame),
            'hud': (context, game) => HudOverlay(game as CycloneGame),
            'controls': (context, game) =>
                ControlsOverlay(game: game as CycloneGame),
            'instructions': (context, game) => InstructionsOverlay(
              onClose: () {
                final g = game as CycloneGame;
                g.showHomeOverlayClean();
              },
            ),
          },
          // No initial overlays; the game runs a startup demo then shows 'home'
          initialActiveOverlays: const [],
        ),
      ),
    );
  }
}
