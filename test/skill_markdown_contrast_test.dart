import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/widgets/group_widgets.dart';
import 'package:hermes_app/src/skills/widgets/skill_markdown_panel.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'bot_mode/group_protocol/groups_repository_test.dart' as fixtures;
import 'support/markdown_contrast.dart';
import 'support/screenshot_recorder.dart';

const _markdown =
    '# Web scraper\n\nFetch pages.\n\n## When to use it\n\n'
    'See [the docs](https://example.com/docs).';

const _texts = ['Web scraper', 'When to use it', 'the docs'];

Future<void> _pump(
  WidgetTester tester,
  ScreenshotRecorder shots,
  Widget body, {
  required bool dark,
}) async {
  await shots.start(tester, const Size(390, 500));
  await tester.pumpWidget(
    shots.frame(
      MaterialApp(
        theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
        home: Scaffold(body: SingleChildScrollView(child: body)),
      ),
    ),
  );
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('skill markdown headings and links are readable in $mode', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('skill-markdown-$mode');
      await _pump(
        tester,
        shots,
        const SkillMarkdownPanel(text: _markdown),
        dark: dark,
      );
      await shots.capture(tester, 'headings');
      expectReadableOnSurface(tester, _texts);
    });

    testWidgets('group event markdown is readable in $mode', (tester) async {
      final shots = ScreenshotRecorder('group-event-$mode');
      final event = GroupEvent.fromJson({
        ...fixtures.event(1, kind: 'message.assistant'),
        'actor': {'kind': 'member', 'id': 'one'},
        'payload': {'text': _markdown},
      });
      await _pump(
        tester,
        shots,
        GroupEventRow(
          event: event,
          members: [GroupMember.fromJson(fixtures.member('one'))],
        ),
        dark: dark,
      );
      await shots.capture(tester, 'event');
      expectReadableOnSurface(tester, _texts);
    });
  }
}
