import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';

import 'support/fake_hermes_server.dart';

void main() {
  test(
    'the watch names the launch profile, not the sticky active one',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/profiles/active', {
          'active': 'main',
          'current': 'work',
        });

      expect(await watchProfile(server.client()), 'work');
    },
  );

  test('a server with no profile routes gives the watch no profile', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'detail': 'x'}, status: 404);

    expect(await watchProfile(server.client()), isNull);
  });
}
