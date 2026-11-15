import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';
import 'package:hermes_app/src/tools/tools_availability.dart';
import 'package:provider/provider.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../tools/tools_screen_fixtures.dart';

/// Tools opened from a chat with no profile of its own read the launch
/// profile, even when the shell's list was last read for another one.
void main() {
  testWidgets('Tools opens on the launch profile, not the one last read', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'main', 'current': 'work'})
      ..on('GET', '/api/sessions', sessionListBody([]));
    routeTools(server);
    final repositories = HermesRepositories(server.client());
    final availability = ToolsAvailability(repositories.tools);
    addTearDown(availability.dispose);
    // The list the shell read earlier, for another profile.
    await tester.runAsync(() => availability.refresh(resolvedProfile('other')));
    server.requests.clear();

    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: FakeChatTransport(),
      providers: [
        Provider<HermesRepositories?>.value(value: repositories),
        ChangeNotifierProvider<ToolsAvailability?>.value(value: availability),
      ],
    );
    await openSidebarMore(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Tools'),
      ),
    );
    await tester.pumpAndSettle();

    final reads = server.requestsTo('GET', '/api/tools/toolsets').toList();
    expect(reads, isNotEmpty);
    expect(reads.map((r) => r.queryParameters['profile']).toSet(), {'work'});
  });
}
