import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/macos/mac_source_list.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

/// The thread list of the Mac sidebar: sections by recency, 28pt rows with
/// hover buttons and a Mac context menu.
void main() {
  late FakeHermesServer server;
  final now = DateTime.now().millisecondsSinceEpoch / 1000;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'p1', title: 'Pinned plan', pinned: true),
          sessionRow(id: 's1', title: 'Run failure', lastActive: now - 60),
          sessionRow(id: 's2', title: 'Release notes', lastActive: now - 120),
          sessionRow(
            id: 's3',
            title: 'Trip plan',
            lastActive: now - 90 * 86400,
          ),
        ]),
      );
    for (final id in ['p1', 's1', 's2', 's3']) {
      server.on(
        'GET',
        '/api/sessions/$id/messages',
        messageListBody(id, [
          messageRow(id: 1, role: 'user', content: 'hi'),
          messageRow(id: 2, role: 'assistant', content: 'Hello there'),
        ]),
      );
    }
  });

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
          home: MacSidebarScope(
            child: ChatScreen(
              repository: HermesChatRepository(server.client().raw),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('thread-$id'));
  Finder header(String label) => find.byKey(ValueKey('thread-section-$label'));

  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(target));
    await tester.pumpAndSettle();
    return mouse;
  }

  Future<void> rightClick(WidgetTester tester, String id) async {
    await tester.tap(row(id), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  testWidgets('sorts threads under Pinned, Today and Older', (tester) async {
    await pump(tester);

    expect(header('Pinned'), findsOneWidget);
    expect(header('Today'), findsOneWidget);
    expect(header('Older'), findsOneWidget);
    expect(header('Previous 7 days'), findsNothing);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(header('Pinned')), lessThan(top(row('p1'))));
    expect(top(row('p1')), lessThan(top(header('Today'))));
    expect(top(header('Today')), lessThan(top(row('s1'))));
    expect(top(row('s2')), lessThan(top(header('Older'))));
    expect(top(header('Older')), lessThan(top(row('s3'))));
    expect(tester.getSize(row('s1')).height, 28);
  });

  testWidgets('other platforms keep the flat list', (tester) async {
    await pump(tester, platform: TargetPlatform.windows);
    expect(header('Today'), findsNothing);
    expect(row('s1'), findsOneWidget);
  });

  testWidgets('a header folds its section away, and that is remembered', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(header('Today'));
    await tester.pumpAndSettle();

    expect(row('s1'), findsNothing);
    expect(row('s3'), findsOneWidget);
    expect(
      await SharedPreferencesAsync().getStringList(
        'hermes.mac_sidebar_folded_sections',
      ),
      ['today'],
    );

    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(row('s1'), findsNothing);
    await tester.tap(header('Today'));
    await tester.pumpAndSettle();
    expect(row('s1'), findsOneWidget);
  });

  testWidgets('hovering a row shows Archive, which archives it', (
    tester,
  ) async {
    server.on(
      'PATCH',
      '/api/sessions/s2',
      sessionPatchBody(flags: {'archived': true}),
    );
    await pump(tester);
    final archive = find.descendant(
      of: row('s2'),
      matching: find.byTooltip('Archive'),
    );
    expect(tester.widget<Visibility>(_visibility(archive)).visible, isFalse);

    await hover(tester, row('s2'));
    expect(tester.widget<Visibility>(_visibility(archive)).visible, isTrue);
    expect(
      find.descendant(of: row('s2'), matching: find.byTooltip('More')),
      findsOneWidget,
    );
    await tester.tap(archive);
    await tester.pumpAndSettle();

    expect(jsonBody(server.requestsTo('PATCH', '/api/sessions/s2').single), {
      'archived': true,
    });
    expect(row('s2'), findsNothing);
  });

  testWidgets('a right-click opens the Mac menu, in order', (tester) async {
    await pump(tester);
    await rightClick(tester, 's2');

    final labels = ['Rename…', 'Pin', 'Copy Transcript', 'Archive', 'Delete…'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final tops = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
    expect(tops, [...tops]..sort());
    expect(find.text('⇧⌘P'), findsOneWidget);
    expect(find.text('⌘⌫'), findsOneWidget);
    expect(find.text('Open in New Window'), findsNothing);
  });

  testWidgets('a pinned thread offers Unpin', (tester) async {
    await pump(tester);
    await rightClick(tester, 'p1');
    expect(find.text('Unpin'), findsOneWidget);
  });

  group('Copy Transcript', () {
    late List<String> copied;

    setUp(() => copied = []);

    void captureClipboard(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('loads a thread that is not open and copies Markdown', (
      tester,
    ) async {
      captureClipboard(tester);
      await pump(tester);
      expect(server.requestsTo('GET', '/api/sessions/s2/messages'), isEmpty);

      await rightClick(tester, 's2');
      await tester.tap(find.text('Copy Transcript'));
      await tester.pumpAndSettle();

      expect(copied, ['## You\n\nhi\n\n## Hermes\n\nHello there']);
      expect(find.text('Transcript copied'), findsOneWidget);
    });

    testWidgets('waits for a thread that is still loading', (tester) async {
      captureClipboard(tester);
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'GET',
        '/api/sessions/s1/messages',
        (_) => answer.future,
      );
      await pump(tester);
      await tester.tap(row('s1'));
      await tester.pump();

      await rightClick(tester, 's1');
      await tester.tap(find.text('Copy Transcript'));
      await tester.pump();
      answer.complete((
        status: 200,
        body: messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'hi'),
        ]),
      ));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('GET', '/api/sessions/s1/messages'),
        hasLength(1),
      );
      expect(copied, ['## You\n\nhi']);
    });

    testWidgets('does not fetch an open thread again', (tester) async {
      captureClipboard(tester);
      await pump(tester);
      await tester.tap(row('s1'));
      await tester.pumpAndSettle();
      expect(
        server.requestsTo('GET', '/api/sessions/s1/messages'),
        hasLength(1),
      );

      await rightClick(tester, 's1');
      await tester.tap(find.text('Copy Transcript'));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('GET', '/api/sessions/s1/messages'),
        hasLength(1),
      );
      expect(copied, ['## You\n\nhi\n\n## Hermes\n\nHello there']);
    });
  });

  testWidgets('Open in New Window shows only with a handler, and calls it', (
    tester,
  ) async {
    final opened = <String>[];
    final thread = ChatThread(
      id: 's9',
      title: 'Window me',
      updatedAt: DateTime.now(),
      remote: true,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: ThreadSidebar(
              threads: [thread],
              selectedId: null,
              onSelect: (_) {},
              onNewThread: () {},
              onOpenInNewWindow: (t) => opened.add(t.id),
            ),
          ),
        ),
      ),
    );
    await rightClick(tester, 's9');

    expect(find.text('⌥⌘O'), findsOneWidget);
    await tester.tap(find.text('Open in New Window'));
    await tester.pumpAndSettle();
    expect(opened, ['s9']);
  });

  test('ThreadAction lists opening in a new window', () {
    expect(ThreadAction.values, contains(ThreadAction.openInNewWindow));
  });

  group('destinations', () {
    Future<void> pumpNavigation(WidgetTester tester, TargetPlatform platform) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildHermesLightTheme(platform: platform),
            home: Scaffold(
              body: ShellNavigation(
                destinations: const [
                  (
                    icon: AppIcons.chat,
                    selected: AppIcons.chatFilled,
                    label: 'Chat',
                    caption: null,
                  ),
                  (
                    icon: AppIcons.kanban,
                    selected: AppIcons.kanbanFilled,
                    label: 'Kanban',
                    caption: 'All profiles',
                  ),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        );

    testWidgets('are 28pt source-list rows with a caption on macOS', (
      tester,
    ) async {
      await pumpNavigation(tester, TargetPlatform.macOS);
      expect(tester.getSize(find.byType(MacSourceListRow).first).height, 28);
      expect(find.text('All profiles'), findsOneWidget);
    });

    testWidgets('keep the sidebar actions elsewhere', (tester) async {
      await pumpNavigation(tester, TargetPlatform.windows);
      expect(find.byType(MacSourceListRow), findsNothing);
      expect(find.text('All profiles'), findsNothing);
    });
  });
}

Finder _visibility(Finder inside) =>
    find.ancestor(of: inside, matching: find.byType(Visibility)).first;
