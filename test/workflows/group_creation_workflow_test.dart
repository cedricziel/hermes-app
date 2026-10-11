import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/group_rooms_panel.dart';

import '../bot_mode/group_protocol/groups_repository_test.dart' as fixtures;
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

void main() {
  for (final (label, size, platform, brightness) in [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('desktop', desktopSize, TargetPlatform.macOS, Brightness.light),
    ('phone-dark', phoneSize, TargetPlatform.iOS, Brightness.dark),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ]) {
    testWidgets('group creation $label', (tester) async {
      final shots = ScreenshotRecorder('group-creation-$label');
      final repository = HermesGroupsRepository(
        (method, _) async => switch (method) {
          'groups.capabilities' => fixtures.capabilities(),
          'groups.list' => {'rooms': [], 'next_offset': null},
          _ => throw StateError(method),
        },
      );
      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: ListView(
            children: [
              GroupRoomsPanel(
                repository: repository,
                bots: const [
                  BotModeBot(serverId: 'demo', name: 'writer', revision: 1),
                  BotModeBot(serverId: 'demo', name: 'research', revision: 1),
                  BotModeBot(serverId: 'demo', name: 'reviewer', revision: 1),
                ],
                onOpen: (_) {},
              ),
            ],
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'create');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
