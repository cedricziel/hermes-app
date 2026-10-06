import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profiles_view.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../widgetbook/catalog_auth.dart';
import 'support/fake_hermes_server.dart';

/// Profile scope in a Mac window: the switcher at the top of the sidebar, the
/// Profiles page, and the account footer.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true, skillCount: 7),
          profileRow(name: 'work', description: 'Day job', skillCount: 12),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('POST', '/api/profiles/active', {'ok': true})
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'd1', title: 'Home chat')]),
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'w1', title: 'Office chat')]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'grafana', url: 'https://mcp.test/mcp'),
        ]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(id: 'telegram', name: 'Telegram', enabled: true),
          platformRow(id: 'slack', name: 'Slack'),
        ]),
      )
      ..on(
        'GET',
        '/api/model/auxiliary',
        {'detail': 'down'},
        status: 500,
        query: {'profile': 'work'},
      );
  });

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = CatalogAuth(server: server, gated: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      withAppProviders(
        auth,
        MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inSidebar(Finder finder) =>
      find.descendant(of: find.byType(ThreadSidebar), matching: finder);

  testWidgets('the switcher sits above the destinations', (tester) async {
    await pump(tester);
    final switcher = find.byKey(const Key('mac-profile-switcher'));
    expect(switcher, findsOneWidget);
    expect(
      tester.getTopLeft(switcher).dy,
      lessThan(tester.getTopLeft(inSidebar(find.text('Chat'))).dy),
    );
    expect(inSidebar(find.text('Profiles')), findsOneWidget);
  });

  testWidgets('switching makes the profile active and lists its chats', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Home chat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mac-profile-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('work').last);
    await tester.pumpAndSettle();

    expect(jsonBody(server.requestsTo('POST', '/api/profiles/active').single), {
      'name': 'work',
    });
    expect(find.text('Office chat'), findsOneWidget);
    expect(find.text('Home chat'), findsNothing);
  });

  testWidgets('the sidebar has no management rows on macOS', (tester) async {
    await pump(tester);
    expect(inSidebar(find.text('More')), findsNothing);
    expect(inSidebar(find.text('Skills')), findsNothing);
  });

  testWidgets('other platforms keep them and have no switcher', (tester) async {
    await pump(tester, platform: TargetPlatform.windows);
    expect(find.byKey(const Key('mac-profile-switcher')), findsNothing);
    expect(inSidebar(find.text('More')), findsOneWidget);
  });

  testWidgets('the Profiles page counts what a profile holds', (tester) async {
    await pump(tester);
    await tester.tap(inSidebar(find.text('Profiles')));
    await tester.pumpAndSettle();
    expect(find.text('2 profiles on hermes.example.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-row-work')));
    await tester.pumpAndSettle();

    String? countIn(ProfileSection section) {
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey('profile-section-${section.name}')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      return texts.length > 2 ? texts.last : null;
    }

    expect(countIn(ProfileSection.skills), '12');
    expect(countIn(ProfileSection.mcp), '1');
    expect(countIn(ProfileSection.helperModels), isNull);
    expect(countIn(ProfileSection.messaging), isNull);

    await tester.tap(find.byKey(const ValueKey('profile-row-default')));
    await tester.pumpAndSettle();
    expect(countIn(ProfileSection.messaging), '1');
  });

  testWidgets('the account footer opens Settings', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('mac-account-footer')).first);
    await tester.pumpAndSettle();
    expect(find.text('Signed in to the dashboard'), findsOneWidget);

    await tester.tap(find.text('Settings…'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance…'), findsOneWidget);
    expect(find.text('About Hermes'), findsOneWidget);
  });
}
