import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import '../support/pump_chat.dart';
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
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/profiles', {
        'profiles': [profileRow(name: 'work')],
      })
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/skills', <Object?>[])
      ..on('GET', '/api/learning/graph', memoryGraph);
  });

  Future<void> pumpChat(WidgetTester tester, {Size? size}) => pumpChatScreen(
    tester,
    server: server,
    transport: transport,
    size: size ?? const Size(1400, 900),
    providers: [
      ChangeNotifierProvider<AuthController>(
        create: (_) => ProtectedCatalogAuth(server),
      ),
    ],
  );

  Finder inSidebar(String label) => find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.text(label),
  );

  int reads() =>
      transport.slashRuns.where((c) => c == '/memory pending').length;

  testWidgets(
    'the More section reads Memory · 2 waiting for the chat profile',
    (tester) async {
      await pumpChat(tester);
      await openSidebarMore(tester);

      expect(inSidebar('Memory · 2 waiting'), findsOneWidget);
      expect(inSidebar('Memory'), findsNothing);
      expect(transport.asked.map((a) => a.$2).toSet(), {'work'});
    },
  );

  testWidgets('the phone drawer shows the count too', (tester) async {
    await pumpChat(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('shell-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Memory · 2 waiting'), findsOneWidget);
  });

  testWidgets('nothing waiting leaves the plain label', (tester) async {
    transport.script['/memory pending'] = noPendingMemory;
    await pumpChat(tester);
    await openSidebarMore(tester);

    expect(inSidebar('Memory'), findsOneWidget);
  });

  testWidgets('a count that cannot be read shows nothing', (tester) async {
    transport.script['/memory pending'] = StateError('socket');
    transport.script['/skills pending'] = StateError('socket');
    await pumpChat(tester);
    await openSidebarMore(tester);

    expect(inSidebar('Memory'), findsOneWidget);
  });

  testWidgets('coming back to the app soon does not read again', (
    tester,
  ) async {
    await pumpChat(tester);
    final before = reads();

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(before, greaterThan(0));
    expect(reads(), before);
  });

  testWidgets('leaving Memory reads the count again', (tester) async {
    await pumpChat(tester);
    await openSidebarMore(tester);
    final before = reads();

    await tester.tap(inSidebar('Memory · 2 waiting'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDestination), findsOneWidget);
    transport.script['/memory pending'] = noPendingMemory;
    final inboxReads = reads();
    expect(inboxReads, greaterThan(before));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(reads(), greaterThan(inboxReads));
    await openSidebarMore(tester);
    expect(inSidebar('Memory'), findsOneWidget);
  });
}
