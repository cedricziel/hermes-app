import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';
import 'package:provider/provider.dart';

import '../memory/memory_fixtures.dart';
import '../memory/memory_proposal_fixtures.dart';
import '../memory/memory_proposal_support.dart';
import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import '../support/pump_chat.dart';

const _two =
    'Pending memory writes (2):\n'
    '  aa000001  add to user profile: Runs on a Mac\n'
    '  aa000002  add to memory: Other\n';

/// The Memory entry of a chat with no profile of its own counts the changes
/// waiting in the launch profile, never in the sticky `active` one and never
/// in a profile named `default` by hand. With no profile known it asks nothing.
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
      // The chat reads no profile of its own from this, so the resolver
      // handed to the screen is what names one.
      ..on('GET', '/api/profiles/active', {'detail': 'x'}, status: 404)
      ..on('GET', '/api/skills', <Object?>[])
      ..on('GET', '/api/learning/graph', memoryGraph);
  });

  Future<void> pumpChat(WidgetTester tester, ProfileResolver resolver) =>
      pumpChatScreen(
        tester,
        server: server,
        transport: transport,
        profileResolver: resolver,
        size: const Size(1400, 900),
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

  testWidgets('a chat with no profile counts the launch profile work', (
    tester,
  ) async {
    await pumpChat(tester, ProfileResolver.known('work'));
    await openSidebarMore(tester);

    expect(inSidebar('Memory · 2 waiting'), findsOneWidget);
    expect(transport.asked.map((a) => a.$2).toSet(), {'work'});
  });

  testWidgets('a chat with no profile and no launch profile asks nothing', (
    tester,
  ) async {
    final options = RequestOptions(path: '/api/profiles/active');
    await pumpChat(
      tester,
      ProfileResolver(
        () => Future.error(
          DioException(
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 404,
            ),
          ),
        ),
      ),
    );
    await openSidebarMore(tester);

    expect(transport.asked, isEmpty);
    expect(inSidebar('Memory'), findsOneWidget);
  });

  testWidgets('the count shows once a launch profile read that failed '
      'succeeds', (tester) async {
    var reads = 0;
    final resolver = ProfileResolver(() async {
      if (reads++ == 0) {
        final options = RequestOptions(path: '/api/profiles/active');
        throw DioException(
          requestOptions: options,
          response: Response<Object?>(requestOptions: options, statusCode: 500),
        );
      }
      return (active: 'main', current: 'work');
    });
    await pumpChat(tester, resolver);
    await openSidebarMore(tester);
    await expectLater(resolver.load(), throwsA(isA<DioException>()));
    await tester.pumpAndSettle();
    expect(transport.asked, isEmpty);
    expect(inSidebar('Memory'), findsOneWidget);

    await tester.runAsync(resolver.load);
    await tester.pumpAndSettle();

    expect(inSidebar('Memory · 2 waiting'), findsOneWidget);
    expect(transport.asked.map((a) => a.$2).toSet(), {'work'});
    expect(reads, 2);
  });
}
