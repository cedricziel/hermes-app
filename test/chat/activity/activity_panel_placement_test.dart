import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';

import '../../support/pump_chat.dart';

const _thread = "Summarize last night's run logs";
final _panel = find.byKey(const Key('activity-panel'));
final _inspector = find.byKey(const Key('activity-inspector'));

void main() {
  late BreadcrumbTrail trail;
  setUp(() => trail = BreadcrumbTrail());
  List<String> crumbs() => [
    for (final c in trail.recent)
      if (c.name.startsWith('chat.activity')) '${c.name} ${c.attributes}',
  ];

  Future<void> pump(
    WidgetTester tester, {
    MacCommandRegistry? commands,
    TargetPlatform? platform,
  }) => pumpChatScreen(
    tester,
    commands: commands,
    platform: platform,
    providers: [Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail))],
  );

  testWidgets(
    'the inspector docks beside a wide chat and stays open across chats',
    (tester) async {
      await pump(tester);
      await openThread(tester, _thread);
      await tester.tap(find.byKey(const Key('header-activity')));
      await tester.pumpAndSettle();
      expect(_inspector, findsOneWidget);
      expect(find.descendant(of: _inspector, matching: _panel), findsOne);

      await openThread(tester, 'Draft release notes for v0.9');
      expect(_inspector, findsOneWidget);

      await tester.tap(find.byKey(const Key('header-activity')));
      await tester.pumpAndSettle();
      expect(_inspector, findsNothing);
      expect(crumbs(), [
        'chat.activity.opened {surface: inspector, source: button}',
        'chat.activity.closed {surface: inspector}',
      ]);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('a phone opens the panel as a sheet (${platform.name})', (
      tester,
    ) async {
      await pump(tester, platform: platform);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('header-activity')));
      await tester.pumpAndSettle();
      expect(_panel, findsOneWidget);
      expect(_inspector, findsNothing);
      expect(find.byKey(const Key('activity-close')), findsOneWidget);

      await tester.tap(find.byKey(const Key('activity-close')));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(crumbs(), [
        'chat.activity.opened {surface: sheet, source: button}',
        'chat.activity.closed {surface: sheet}',
      ]);
    });
  }

  testWidgets('View > Inspector toggles the chat inspector', (tester) async {
    final commands = MacCommandRegistry();
    addTearDown(commands.dispose);
    await pump(tester, commands: commands, platform: TargetPlatform.macOS);

    await openThread(tester, _thread);
    expect(commands.invoke(MacCommand.toggleInspector), isTrue);
    await tester.pumpAndSettle();
    expect(_inspector, findsOneWidget);
    expect(
      commands.handlerFor(MacCommand.toggleInspector)?.title,
      'Hide Inspector',
    );
    expect(crumbs(), [
      'chat.activity.opened {surface: inspector, source: menu}',
    ]);
  });
}
