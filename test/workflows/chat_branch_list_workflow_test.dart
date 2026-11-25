import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// A chat that was branched from another is marked in the chat list and in
/// the search results; a compression continuation is not.
void main() {
  for (final (name, size) in [
    // A Mac window is never phone-wide, and has no phone drawer.
    if (workflowPlatform != TargetPlatform.macOS) ('phone', phoneSize),
    ('desktop', desktopSize),
  ]) {
    testWidgets('$name: a branch is marked in the list and the search', (
      tester,
    ) async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(
              id: 'p',
              title: 'Backup failure',
              lastActive: 1780000900,
              pinned: true,
            ),
            {
              ...sessionRow(
                id: 'b',
                title: 'Backup failure: try the old certificate',
                lastActive: 1780000800,
              ),
              '_branched_from': 'p',
            },
            {
              ...sessionRow(
                id: 'c',
                title: 'Release notes for the staging cluster',
                lastActive: 1780000700,
              ),
              'parent_session_id': 'q',
            },
            sessionRow(id: 'n', title: 'Plan the week', lastActive: 1780000600),
          ]),
        )
        ..on('GET', '/api/sessions/search', {
          'results': [
            {
              'session_id': 'b',
              'title': 'Backup failure: try the old certificate',
              'snippet': 'pin the old >>>certificate<<< for the backup agent',
              'session_started': 1780000000,
            },
            {
              'session_id': 'n',
              'title': 'Plan the week',
              'snippet': 'renew the >>>certificate<<< on Friday',
              'session_started': 1780000000,
            },
          ],
        });
      final shots = ScreenshotRecorder('chat-branch-list-$name');
      await pumpScreen(
        tester,
        shots,
        ChatScreen(
          repository: HermesChatRepository(server.client().raw),
          transport: FakeChatTransport(),
        ),
        size: size,
      );
      await openSidebar(tester);
      expect(findAppIcon(AppIcons.branch), findsOneWidget);
      await shots.capture(tester, 'list');

      final mac = workflowPlatform == TargetPlatform.macOS;
      if (mac) {
        final field = find.byKey(const Key('toolbar-search-field'));
        if (field.evaluate().isEmpty) {
          await tester.tap(find.byKey(const Key('toolbar-search')));
          await tester.pumpAndSettle();
        }
      }
      await tester.enterText(
        find.byKey(Key(mac ? 'toolbar-search-field' : 'thread-search-field')),
        'certificate',
      );
      await tester.pump(ThreadSearch.defaultDebounce);
      await tester.pumpAndSettle();
      expect(findAppIcon(AppIcons.branch), findsOneWidget);
      await shots.capture(tester, 'search');
    });
  }
}
