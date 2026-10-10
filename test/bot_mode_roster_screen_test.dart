import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

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
    expect(find.text('Add an existing profile'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'nobody');
    await tester.pump();
    expect(find.text('Editor'), findsNothing);
  });

  testWidgets('adds an existing profile from its row', (tester) async {
    final saved = <Map<String, Object?>>[];
    var added = false;
    final repository = BotModeRosterRepository((method, params) async {
      if (method == 'profiles.list') {
        return {
          'bot_mode_protocol': true,
          'profiles': [
            {
              'name': 'plain',
              'ui_meta_revisions': {'hermes-bots': added ? 1 : 0},
              if (added)
                'ui_meta': {
                  'hermes-bots': {'title': 'plain'},
                },
            },
          ],
        };
      }
      saved.add({'method': method, ...params});
      added = true;
      return {
        'applied': {'ui_meta': true},
      };
    }, serverId: 'local');
    await tester.pumpWidget(
      MaterialApp(home: BotModeRosterScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single['name'], 'plain');
    expect(find.text('Add an existing profile'), findsNothing);
    // The profile is now a bot: one row, with the bot's Edit button.
    final row = find.byType(GroupedRow);
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('plain')),
      findsWidgets,
    );
    expect(
      find.descendant(of: row, matching: find.byTooltip('Edit bot')),
      findsOneWidget,
    );
    expect(find.text('Add'), findsNothing);
  });

  for (final (count, subtitle) in [(1, '1 bot'), (2, '2 bots')]) {
    testWidgets('the Mac subtitle counts $count as "$subtitle"', (
      tester,
    ) async {
      final repository = BotModeRosterRepository(
        (_, _) async => {
          'bot_mode_protocol': true,
          'profiles': [
            for (var i = 0; i < count; i++)
              {
                'name': 'bot$i',
                'ui_meta_revisions': {'hermes-bots': 1},
                'ui_meta': {
                  'hermes-bots': {'title': 'Bot $i'},
                },
              },
          ],
        },
        serverId: 'local',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: BotModeRosterScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(subtitle), findsOneWidget);
    });
  }

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
  testWidgets('non-string presentation summary does not break the roster', (
    tester,
  ) async {
    final repository = BotModeRosterRepository(
      (_, _) async => {
        'bot_mode_protocol': true,
        'profiles': [
          {
            'name': 'writer',
            'description': 'Server description',
            'ui_meta_revisions': {'hermes-bots': 1},
            'ui_meta': {
              'hermes-bots': {'title': 'Editor', 'description': 12},
            },
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
    expect(find.text('Server description'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
