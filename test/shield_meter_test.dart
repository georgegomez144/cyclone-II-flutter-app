import 'package:cyclone_game/game/game_manager.dart';
import 'package:cyclone_game/game/ui/shield_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows pickup shield and reverts to ship shields when depleted', (
    tester,
  ) async {
    final gameManager = GameManager()..shields.value = 72;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShieldMeter(gameManager: gameManager)),
      ),
    );

    expect(find.text('72%'), findsOneWidget);
    var icon = tester.widget<Icon>(find.byIcon(Icons.shield));
    var indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(icon.color, Colors.amber);
    expect(indicator.valueColor!.value, Colors.amber);
    expect(indicator.value, 0.72);

    gameManager.playerShield.value = 65;
    await tester.pump();

    expect(find.text('65%'), findsOneWidget);
    icon = tester.widget<Icon>(find.byIcon(Icons.shield));
    indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(icon.color, Colors.lightBlueAccent);
    expect(indicator.valueColor!.value, Colors.lightBlueAccent);
    expect(indicator.value, 0.65);

    gameManager.playerShieldCount.value = 2;
    await tester.pump();
    expect(find.text('65% x2'), findsOneWidget);

    gameManager.playerShield.value = 0;
    gameManager.playerShieldCount.value = 0;
    await tester.pump();

    expect(find.text('72%'), findsOneWidget);
    icon = tester.widget<Icon>(find.byIcon(Icons.shield));
    indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(icon.color, Colors.amber);
    expect(indicator.valueColor!.value, Colors.amber);
    expect(indicator.value, 0.72);
  });
}
