import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

class HomeMenu extends StatefulWidget {
  const HomeMenu({super.key, required this.game});
  final CycloneGame game;

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  late final TextEditingController _nameCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.game.gm.lastPlayerName.value);
    widget.game.gm.lastPlayerName.addListener(_onNameFromModel);
  }

  void _onNameFromModel() {
    if (_nameCtl.text != widget.game.gm.lastPlayerName.value) {
      _nameCtl.text = widget.game.gm.lastPlayerName.value;
    }
  }

  @override
  void dispose() {
    widget.game.gm.lastPlayerName.removeListener(_onNameFromModel);
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gm = widget.game.gm;
    return Material(
      color: Colors.black,
      child: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Cyclone',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _highScores(gm),
                    const SizedBox(height: 16),
                    _lastPlayer(gm),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _redButton(
                          label: 'Start New Game',
                          onPressed: () {
                            gm.savePrefs();
                            widget.game.startGame();
                          },
                        ),
                        _redButton(
                          label: 'Instructions',
                          onPressed: () {
                            widget.game.overlays.remove('home');
                            widget.game.overlays.add('instructions');
                          },
                        ),
                        _redButton(
                          label: 'Clear High Score List',
                          onPressed: () {
                            gm.clearHighScores();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _settings(gm),
                    const SizedBox(height: 24),
                    _lastPlayerSummary(gm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lastPlayerSummary(GameManager gm) {
    return ValueListenableBuilder3<String, int, int>(
      a: gm.lastPlayerName,
      b: gm.lastScore,
      c: gm.lastLevel,
      builder: (context, name, score, level) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Last Player',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text('Name: $name', style: const TextStyle(color: Colors.amber)),
          Text('Score: $score', style: const TextStyle(color: Colors.amber)),
          Text('Level: $level', style: const TextStyle(color: Colors.amber)),
        ],
      ),
    );
  }

  Widget _highScores(GameManager gm) {
    return ValueListenableBuilder<List<HighScoreEntry>>(
      valueListenable: gm.highScores,
      builder: (context, list, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'High Scores',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Text(
                'No scores yet',
                style: TextStyle(color: Colors.amberAccent),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < list.length && i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        '${i + 1}. ${list[i].name} — ${list[i].score} (L${list[i].level})',
                        style: const TextStyle(color: Colors.amber),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: gm.lastPlayerName,
              builder: (context, last, _) => Text(
                'Last Player: $last',
                style: const TextStyle(color: Colors.amberAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _lastPlayer(GameManager gm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Name', style: TextStyle(color: Colors.amber)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtl,
          style: const TextStyle(color: Colors.amber),
          cursorColor: Colors.amber,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black,
            hintText: 'Enter your name',
            hintStyle: const TextStyle(color: Colors.amberAccent),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.amber),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.amberAccent, width: 2),
            ),
          ),
          onChanged: (v) {
            gm.lastPlayerName.value = v;
          },
          onSubmitted: (_) => gm.savePrefs(),
        ),
      ],
    );
  }

  Widget _settings(GameManager gm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Volume
        ValueListenableBuilder<double>(
          valueListenable: gm.volume,
          builder: (context, vol, _) => Row(
            children: [
              const Text('Volume', style: TextStyle(color: Colors.amber)),
              Expanded(
                child: Slider(
                  value: vol,
                  onChanged: (v) => gm.volume.value = v,
                  onChangeEnd: (_) => gm.savePrefs(),
                  activeColor: Colors.red,
                  inactiveColor: Colors.red.shade200,
                ),
              ),
              Text(
                (vol * 100).round().toString(),
                style: const TextStyle(color: Colors.amber),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Difficulty
        ValueListenableBuilder<Difficulty>(
          valueListenable: gm.difficulty,
          builder: (context, diff, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Difficulty', style: TextStyle(color: Colors.amber)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in Difficulty.values)
                    ChoiceChip(
                      label: Text(
                        _diffLabel(option),
                        style: const TextStyle(color: Colors.black),
                      ),
                      selected: diff == option,
                      selectedColor: Colors.red,
                      backgroundColor: Colors.red.shade200,
                      onSelected: (_) {
                        gm.difficulty.value = option;
                        gm.savePrefs();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _diffLabel(Difficulty d) {
    switch (d) {
      case Difficulty.boring:
        return 'boring';
      case Difficulty.challenging:
        return 'challenging';
      case Difficulty.frustrating:
        return 'frustrating';
    }
  }

  Widget _redButton({required String label, required VoidCallback onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class ValueListenableBuilder3<A, B, C> extends StatelessWidget {
  const ValueListenableBuilder3({
    super.key,
    required this.a,
    required this.b,
    required this.c,
    required this.builder,
  });

  final ValueListenable<A> a;
  final ValueListenable<B> b;
  final ValueListenable<C> c;
  final Widget Function(BuildContext, A, B, C) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: a,
      builder: (context, va, _) => ValueListenableBuilder<B>(
        valueListenable: b,
        builder: (context, vb, __) => ValueListenableBuilder<C>(
          valueListenable: c,
          builder: (context, vc, ___) => builder(context, va, vb, vc),
        ),
      ),
    );
  }
}
