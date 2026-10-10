import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/quick_actions/quick_actions_items.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_builder.dart';

import '../support/fake_hermes_server.dart';

void main() {
  test('a chat without a server title shows the fixed label', () async {
    const prompt = 'Email the board the secret quarterly numbers';
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [
          {'name': 'default'},
        ],
      })
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', preview: prompt, lastActive: 1780000100),
        ]),
        query: {'profile': 'default'},
      )
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/cron/delivery-targets', {'targets': []})
      ..on('GET', '/api/cron/jobs', []);
    final built = await SurfaceSnapshotBuilder(
      HermesRepositories(server.client()),
      timeout: const Duration(milliseconds: 200),
    ).build(signedIn: true, refreshRemote: true);

    final items = quickActionItems(built.snapshot);

    expect(items.last.localizedTitle, 'New chat');
    expect(
      [for (final i in items) i.localizedTitle].join(),
      isNot(contains('secret')),
    );
  });
}
