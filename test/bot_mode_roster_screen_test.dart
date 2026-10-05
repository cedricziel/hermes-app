import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';

void main() {
  testWidgets('shows managed bots, filters them and offers explicit add', (
    tester,
  ) async {
    final repository = BotModeRosterRepository(
      (_, _) async => {
        'bot_mode_protocol': true,
        'profiles': [
          {
            'name': 'writer',
            'model': 'm',
            'ui_meta_revisions': {'hermes-bots': 2},
            'ui_meta': {
              'hermes-bots': {'title': 'Editor'},
            },
          },
          {
            'name': 'plain',
            'ui_meta_revisions': {'hermes-bots': 0},
          },
        ],
      },
      serverId: 'local',
    );
    await tester.pumpWidget(
      MaterialApp(home: BotModeRosterScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Add profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'nobody');
    await tester.pump();
    expect(find.text('Editor'), findsNothing);
  });

  testWidgets('older gateway explains unavailable state', (tester) async {
    final repository = BotModeRosterRepository(
      (_, _) async => {'profiles': []},
      serverId: 'local',
    );
    await tester.pumpWidget(
      MaterialApp(home: BotModeRosterScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Bot Mode compatible update'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
