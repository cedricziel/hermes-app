import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/widgets/conversation_window_toolbar.dart';

void main() {
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester, {
    bool pinned = false,
    String? subtitle = 'work · hermes-4',
  }) async {
    calls = [];
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: ConversationWindowToolbar(
            title: 'Trip plan',
            subtitle: subtitle,
            pinned: pinned,
            onShowInMain: () => calls.add('main'),
            onTogglePin: () => calls.add('pin'),
            onShare: (_) => calls.add('share'),
            onAction: (action) => calls.add(action.name),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the title and the profile and model under it', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Trip plan'), findsOneWidget);
    expect(find.text('work · hermes-4'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ConversationWindowToolbar)).height,
      kMacToolbarHeight,
    );
  });

  testWidgets('leaves room for the traffic lights', (tester) async {
    await pump(tester);

    expect(
      tester.getTopLeft(find.text('Trip plan')).dx,
      greaterThanOrEqualTo(kMacTrafficLightsWidth),
    );
  });

  testWidgets('names each action with its shortcut', (tester) async {
    await pump(tester);

    expect(find.byTooltip('Show in Main Window'), findsOneWidget);
    expect(find.byTooltip('Pin ⇧⌘P'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('a pinned chat offers Unpin', (tester) async {
    await pump(tester, pinned: true);

    expect(find.byTooltip('Unpin ⇧⌘P'), findsOneWidget);
  });

  testWidgets('the buttons call back', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Show in Main Window'));
    await tester.tap(find.byTooltip('Pin ⇧⌘P'));
    await tester.tap(find.byTooltip('Share'));

    expect(calls, ['main', 'pin', 'share']);
  });

  testWidgets('the more menu holds the thread actions, delete last', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    final labels = ['Rename…', 'Copy Transcript', 'Archive', 'Delete…'];
    final tops = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
    expect(tops, orderedEquals([...tops]..sort()));

    expect(find.text('Pin'), findsNothing);
    await tester.tap(find.text('Delete…'));
    await tester.pumpAndSettle();
    expect(calls, [ThreadAction.delete.name]);
  });

  testWidgets('without a subtitle only the title shows', (tester) async {
    await pump(tester, subtitle: null);

    expect(find.text('Trip plan'), findsOneWidget);
    expect(find.text('work · hermes-4'), findsNothing);
  });
}
