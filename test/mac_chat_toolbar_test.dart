import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    required double width,
    bool searchActive = false,
  }) async {
    final events = <String>[];
    tester.view
      ..physicalSize = Size(width, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: MacChatToolbar(
              title: 'Plan the release',
              subtitle: 'default · claude-sonnet-4',
              onNewChat: () => events.add('new'),
              onShowConnection: () => events.add('connection'),
              onCopyTranscript: () => events.add('copy'),
              searchQuery: '',
              searchActive: searchActive,
              onSearchBegin: () => events.add('begin'),
              onSearchChanged: (q) => events.add('search:$q'),
              onSearchEnd: () => events.add('end'),
            ),
          ),
        ),
      ),
    );
    return events;
  }

  testWidgets('a large window shows every button and the search field', (
    tester,
  ) async {
    final events = await pump(tester, width: 1160);

    expect(find.text('Plan the release'), findsOneWidget);
    expect(find.text('default · claude-sonnet-4'), findsOneWidget);
    expect(find.byType(MacToolbarSearchField), findsOneWidget);
    expect(find.byTooltip('New Chat ⌘N'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toolbar-share')));
    await tester.tap(find.byKey(const Key('toolbar-connection')));
    await tester.tap(find.byKey(const Key('toolbar-new-chat')));
    expect(events, ['copy', 'connection', 'new']);
  });

  testWidgets('a medium window has a search button until a search opens', (
    tester,
  ) async {
    final events = await pump(tester, width: 900);
    expect(find.byType(MacToolbarSearchField), findsNothing);
    await tester.tap(find.byKey(const Key('toolbar-search')));
    expect(events, ['begin']);

    await pump(tester, width: 900, searchActive: true);
    expect(find.byType(MacToolbarSearchField), findsOneWidget);
  });

  testWidgets('a compact window folds Copy Transcript and Connection into …', (
    tester,
  ) async {
    final events = await pump(tester, width: 680);
    expect(find.byKey(const Key('toolbar-share')), findsNothing);
    expect(find.byKey(const Key('toolbar-connection')), findsNothing);

    await tester.tap(find.byKey(const Key('toolbar-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connection Details'));
    await tester.pumpAndSettle();
    expect(events, ['connection']);
  });
}
