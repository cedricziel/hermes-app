import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/mac_profiles_page.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import 'memory_fixtures.dart';
import 'memory_proposal_fixtures.dart';
import 'memory_proposal_support.dart';

const _two =
    'Pending memory writes (2):\n'
    '  aa000001  add to user profile: Runs on a Mac\n'
    '  aa000002  add to memory: Other\n';

void main() {
  late FakeHermesServer server;
  late ScriptedSlashTransport transport;

  setUp(() {
    transport = ScriptedSlashTransport()
      ..script['/memory pending'] = _two
      ..script['/skills pending'] = noPendingSkills;
    server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [profileRow(name: 'work')],
      })
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/learning/graph', memoryGraph);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    bool withTransport = true,
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profiles = ChatProfiles(
      HermesProfilesRepository(server.client().raw),
    );
    addTearDown(profiles.dispose);
    await tester.runAsync(() async {
      await profiles.load();
    });
    profiles.showing('work');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => ProtectedCatalogAuth(server),
          ),
          Provider<HermesRepositories?>.value(
            value: HermesRepositories(server.client()),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: MacProfilesPage(
            profiles: profiles,
            transport: withTransport ? transport : null,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();
  }

  Finder memoryValue(String text) => find.descendant(
    of: find.byKey(const ValueKey('profile-section-memory')),
    matching: find.text(text),
  );

  testWidgets('Memory shows how many changes wait in the selected profile', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(memoryValue('2 waiting'), findsOneWidget);
    expect(transport.asked.map((a) => a.$2).toSet(), {'work'});
  });

  testWidgets('without a count it keeps the entry count', (tester) async {
    transport.script['/memory pending'] = StateError('socket');
    transport.script['/skills pending'] = StateError('socket');
    await pumpPage(tester);

    expect(find.textContaining('waiting'), findsNothing);
    expect(memoryValue('2'), findsOneWidget);
  });

  testWidgets('without a transport nothing is asked', (tester) async {
    await pumpPage(tester, withTransport: false);

    expect(transport.asked, isEmpty);
    expect(find.textContaining('waiting'), findsNothing);
  });

  testWidgets('coming back from Memory counts again', (tester) async {
    await pumpPage(tester);
    transport.script['/memory pending'] = noPendingMemory;

    await tester.tap(find.byKey(const ValueKey('profile-section-memory')));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDestination), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.runAsync(() async {
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('waiting'), findsNothing);
  });
}
