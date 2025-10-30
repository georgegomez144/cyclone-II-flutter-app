import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/ui/hud.dart';
import 'package:cyclone_game/game/ui/home_menu.dart';
import 'package:cyclone_game/game/ui/controls_overlay.dart';
import 'package:cyclone_game/game/ui/instructions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final game = CycloneGame();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
        // Ensure Aldrich applies across all text while keeping amber body color
        textTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Aldrich',
        ).textTheme.apply(bodyColor: Colors.amber),
      ),
      home: Scaffold(
        body: GameWidget(
          game: game,
          overlayBuilderMap: {
            'home': (context, game) => HomeMenu(game: game as CycloneGame),
            'hud': (context, game) => HudOverlay(game as CycloneGame),
            'controls': (context, game) =>
                ControlsOverlay(game: game as CycloneGame),
            'instructions': (context, game) => InstructionsOverlay(
              onClose: () {
                (game as CycloneGame).overlays.remove('instructions');
                game.overlays.add('home');
              },
            ),
          },
          initialActiveOverlays: const ['home'],
        ),
      ),
    ),
  );
}
