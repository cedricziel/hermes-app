import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';

import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

void main() {
  final rows = <Map<String, Object?>>[
    {
      'name': 'writer',
      'display_name': 'Writer',
      'model': 'claude-sonnet-4',
      'provider': 'anthropic',
      'ui_meta_revisions': {'hermes-bots': 3},
      'ui_meta': {
        'hermes-bots': {
          'title': 'Editor',
          'description': 'Clear writing and careful reviews',
        },
      },
      'canonical_session': {
        'id': 'chat-1',
        'preview': 'The draft is ready for review',
      },
    },
    {
      'name': 'research',
      'model': 'gpt-5',
      'ui_meta_revisions': {'hermes-bots': 2},
      'ui_meta': {
        'hermes-bots': {
          'title': 'Researcher',
          'description': 'Sources and synthesis',
        },
      },
    },
    {
      'name': 'plain',
      'ui_meta_revisions': {'hermes-bots': 0},
    },
  ];

  for (final (label, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
    ('desktop-dark', desktopSize, Brightness.dark),
  ]) {
    testWidgets('bot roster $label', (tester) async {
      final shots = ScreenshotRecorder('bot-mode-$label');
      final repository = BotModeRosterRepository((method, _) async {
        if (method == 'profiles.describe') {
          return {
            'name': 'writer',
            'description': 'Edit release notes and prose',
            'soul': 'Write clearly. Check every claim.',
            'model': {'provider': 'anthropic', 'default': 'claude-sonnet-4'},
          };
        }
        return {'bot_mode_protocol': true, 'profiles': rows};
      }, serverId: 'Local Hermes');
      await pumpScreen(
        tester,
        shots,
        BotModeRosterScreen(repository: repository),
        size: size,
        brightness: brightness,
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'roster');
      await tester.tap(find.byTooltip('Edit bot').first);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'editor');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create bot'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'create');
    });
  }
}
