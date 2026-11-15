import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/files/files_availability.dart';
import 'package:provider/provider.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/pump_chat.dart';

const _root = '/srv/field-notes';

/// The Files page of a chat with no profile reads the folder in the profile
/// the dashboard was launched with.
void main() {
  testWidgets('Files reads the launch profile for a chat with none', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'main', 'current': 'work'})
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          {...sessionRow(id: 's1', title: 'Field notes'), 'cwd': _root},
        ]),
      )
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
      ..on('GET', '/api/fs/default-cwd', {'cwd': '/elsewhere'})
      ..on('GET', '/api/fs/git-root', {'root': null})
      ..on('GET', '/api/fs/list', {
        'entries': [
          {'name': 'a.txt', 'path': '$_root/a.txt', 'isDirectory': false},
        ],
      });
    final repositories = HermesRepositories(server.client());
    final availability = FilesAvailability.forRepositories(repositories);
    addTearDown(availability.dispose);
    final dir = tempDir('launch_profile_files');
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: FakeChatTransport(),
      providers: [
        Provider<HermesRepositories?>.value(value: repositories),
        Provider<MediaStore?>.value(
          value: MediaStore(
            source: HermesMediaSource(() => server.client()),
            cacheDirectory: () async => dir,
            actions: FakeMediaActions(),
          ),
        ),
        ChangeNotifierProvider<FilesAvailability?>.value(value: availability),
      ],
    );
    await openThread(tester, 'Field notes');
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if (availability.support != FilesSupport.unknown) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-files-row')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();

    final fs = server.requests
        .where(
          (r) =>
              r.path.startsWith('/api/fs/') && r.path != '/api/fs/default-cwd',
        )
        .toList();
    expect(fs, isNotEmpty);
    expect(fs.map((r) => r.queryParameters['profile']).toSet(), {'work'});
  });
}
