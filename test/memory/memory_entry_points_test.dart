import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import '../support/pump_chat.dart';
import 'memory_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late BreadcrumbTrail trail;

  setUp(() {
    trail = BreadcrumbTrail();
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/profiles', {
        'profiles': [profileRow(name: 'work'), profileRow(name: 'other')],
      })
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/skills', <Object?>[])
      ..on('GET', '/api/learning/graph', memoryGraph);
  });

  Future<void> pumpChat(WidgetTester tester, {Size? size}) => pumpChatScreen(
    tester,
    server: server,
    size: size ?? const Size(1400, 900),
    providers: [
      ChangeNotifierProvider<AuthController>(
        create: (_) => ProtectedCatalogAuth(server),
      ),
      Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
    ],
  );

  double top(WidgetTester tester, String label) => tester
      .getTopLeft(
        find.descendant(
          of: find.byType(ThreadSidebar),
          matching: find.text(label),
        ),
      )
      .dy;

  Iterable<String> crumbs() => trail.recent
      .where((entry) => entry.name == 'nav.memory')
      .map((entry) => '${entry.attributes}');

  group('the More section', () {
    testWidgets('lists Memory directly after Skills', (tester) async {
      await pumpChat(tester);
      await openSidebarMore(tester);

      expect(top(tester, 'Memory'), greaterThan(top(tester, 'Skills')));
      expect(top(tester, 'Memory'), lessThan(top(tester, 'Messaging')));
    });

    testWidgets('opens Memory for the chat profile', (tester) async {
      await pumpChat(tester);
      await openSidebarMore(tester);

      await tester.tap(find.text('Memory'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryDestination), findsOneWidget);
      expect(
        server.requestsTo('GET', '/api/learning/graph').single.queryParameters,
        {'profile': 'work'},
      );
      expect(crumbs(), ['{from: sidebar}']);
    });

    testWidgets('is absent without a dashboard connection', (tester) async {
      await pumpChatScreen(tester);

      expect(find.text('Skills'), findsNothing);
      expect(find.text('Memory'), findsNothing);
    });
  });

  testWidgets('the phone drawer lists Memory between Skills and Messaging', (
    tester,
  ) async {
    await pumpChat(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('shell-menu')));
    await tester.pumpAndSettle();

    final skills = tester.getTopLeft(find.text('Skills')).dy;
    final memory = tester.getTopLeft(find.text('Memory')).dy;
    expect(memory, greaterThan(skills));

    await tester.tap(find.text('Memory'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryDestination), findsOneWidget);
    expect(
      server.requestsTo('GET', '/api/learning/graph').single.queryParameters,
      {'profile': 'work'},
    );
  });

  testWidgets('the Settings dialog has no Memory row', (tester) async {
    await tester.pumpWidget(
      Provider<HermesRepositories?>.value(
        value: HermesRepositories(server.client()),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsDialog(context),
              child: const Text('Settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('setting-appearance')), findsOneWidget);
    expect(find.text('Memory'), findsNothing);
  });
}
