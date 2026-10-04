import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/mac_search_results.dart';
import 'package:hermes_app/src/chat/widgets/thread_search_view.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

/// Searching from the toolbar of a Mac window: Command-F, the results in the
/// sidebar with their scope, Escape, and the compact window's overlay.
void main() {
  late FakeHermesServer server;
  final now = DateTime.now().millisecondsSinceEpoch / 1000;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Release notes', lastActive: now - 60),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/search',
        {
          'results': [
            {
              'session_id': 'd1',
              'title': 'Nightly backup',
              'snippet': 'set up a >>>backup<<<',
              'last_active': now - 100,
            },
          ],
        },
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/sessions/search',
        {
          'results': [
            {
              'session_id': 'w1',
              'title': 'Office notes',
              'snippet': 'the >>>backup<<< of the share',
              'last_active': now - 50,
            },
          ],
        },
        query: {'profile': 'work'},
      );
    for (final id in ['s1', 'd1', 'w1']) {
      server.on(
        'GET',
        '/api/sessions/$id/messages',
        messageListBody(id, [messageRow(id: 1, role: 'user', content: 'hi')]),
      );
    }
  });

  Future<void> pump(WidgetTester tester, {double width = 1200}) async {
    tester.view
      ..physicalSize = Size(width, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = server.client().raw;
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
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: MacSidebarScope(
            child: ChatScreen(
              repository: HermesChatRepository(api),
              profiles: HermesProfilesRepository(api),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> commandF(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('toolbar-search-field')), text);
    await tester.pump(ThreadSearch.defaultDebounce);
    await tester.pumpAndSettle();
  }

  testWidgets('the sidebar has no search field or New chat row', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(ThreadSearchField), findsNothing);
    expect(find.text('New chat'), findsNothing);
    expect(find.byType(MacToolbarSearchField), findsOneWidget);
  });

  testWidgets('Command-F focuses the field and shows recent searches', (
    tester,
  ) async {
    await pump(tester);
    await commandF(tester);

    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('toolbar-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);
    expect(find.byType(MacSearchResults), findsOneWidget);
    expect(find.text('Release notes'), findsNothing);
  });

  testWidgets('results replace the threads, and Escape brings them back', (
    tester,
  ) async {
    await pump(tester);
    await commandF(tester);
    await type(tester, 'backup');

    expect(find.text('Nightly backup'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MacSearchResults), findsNothing);
    expect(find.text('Release notes'), findsOneWidget);
  });

  testWidgets('All profiles names the other profile and opens on it', (
    tester,
  ) async {
    await pump(tester);
    await commandF(tester);
    await type(tester, 'backup');
    await tester.tap(find.text('All profiles'));
    await tester.pumpAndSettle();

    expect(find.text('Office notes'), findsOneWidget);
    expect(find.textContaining('work · ', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Office notes'));
    await tester.pumpAndSettle();
    expect(
      server
          .requestsTo('GET', '/api/sessions')
          .map((r) => r.queryParameters['profile']),
      contains('work'),
    );
  });

  testWidgets('a medium window shows a search button that opens the field', (
    tester,
  ) async {
    await pump(tester, width: 900);
    expect(find.byType(MacToolbarSearchField), findsNothing);
    await tester.tap(find.byKey(const Key('toolbar-search')));
    await tester.pumpAndSettle();
    expect(find.byType(MacToolbarSearchField), findsOneWidget);
  });

  group('in a compact window', () {
    testWidgets('the sidebar opens over the chat and closes on a pick', (
      tester,
    ) async {
      await pump(tester, width: 700);
      expect(find.text('Release notes'), findsNothing);

      await tester.tap(find.byKey(const Key('mac-sidebar-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mac-sidebar-overlay')), findsOneWidget);

      await tester.tap(find.text('Release notes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mac-sidebar-overlay')), findsNothing);
      expect(find.text('Release notes'), findsOneWidget);
    });

    testWidgets('Command-F opens the sidebar for the results', (tester) async {
      await pump(tester, width: 700);
      await commandF(tester);
      expect(find.byKey(const Key('mac-sidebar-overlay')), findsOneWidget);
      expect(find.byType(MacSearchResults), findsOneWidget);
    });
  });
}
