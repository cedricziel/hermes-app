import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/update_check_controller.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late UpdateCheckController controller;

  setUp(() {
    server = FakeHermesServer();
    controller = UpdateCheckController(
      repository: ServerCareRepository(server.client()),
    );
  });

  tearDown(() => controller.dispose());

  UpdateStateAvailable available() =>
      controller.state() as UpdateStateAvailable;

  test('an available update carries the version the check reported', () async {
    server.on('GET', '/api/hermes/update/check', {
      ...updateCheckBehind(),
      'current_version': '0.22.2',
    });
    await controller.check();
    expect(available().currentVersion, '0.22.2');
    expect(available().changeCount, 2);
  });

  test('no version, an empty one or "unknown" is null, never an empty '
      'string', () async {
    for (final v in <Object?>[null, '', 'unknown']) {
      server.on('GET', '/api/hermes/update/check', {
        ...updateCheckBehind(),
        'current_version': v,
      });
      await controller.check();
      expect(available().currentVersion, isNull, reason: '$v');
    }
  });

  test('the fallback version fills in when the check has none', () async {
    server.on('GET', '/api/hermes/update/check', {
      ...updateCheckBehind(),
      'current_version': 'unknown',
    });
    await controller.check();
    final state = controller.state(fallbackVersion: '0.22.1');
    expect((state as UpdateStateAvailable).currentVersion, '0.22.1');
  });
}
