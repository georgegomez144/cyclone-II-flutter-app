import 'package:cyclone_game/game/cyclone_game.dart';
import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/game/ui/hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _HudTestGame extends CycloneGame {
  final GameManager _testManager = GameManager();

  @override
  GameManager get gm => _testManager;
}

void main() {
  testWidgets('macOS HUD pills stay on one row at narrow widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 360, child: HudOverlay(_HudTestGame())),
      ),
    );

    final pills = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).borderRadius != null,
    );
    expect(pills, findsNWidgets(5));

    final topOffsets = pills.evaluate().map((element) {
      final renderBox = element.renderObject! as RenderBox;
      return renderBox.localToGlobal(Offset.zero).dy;
    }).toList();
    for (final topOffset in topOffsets.skip(1)) {
      expect(topOffset, closeTo(topOffsets.first, 0.01));
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
