import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/files/files_availability.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_models.dart';

import '../support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;

  setUp(() => server = FakeHermesServer());

  Future<FilesAvailability> probed() async {
    final availability = FilesAvailability.forRepositories(
      HermesRepositories(server.client()),
    )..ensureProbed();
    addTearDown(availability.dispose);
    for (
      var i = 0;
      i < 200 && availability.support == FilesSupport.unknown;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return availability;
  }

  test('nothing is offered until the probe answers', () {
    final availability = FilesAvailability(
      () => Completer<FilesResult<void>>().future,
    );
    addTearDown(availability.dispose);
    availability.ensureProbed();
    expect(availability.support, FilesSupport.unknown);
    expect(availability.shown, isFalse);
  });

  for (final status in [404, 405]) {
    test('$status means an older Hermes: nothing is shown', () async {
      server.on('GET', '/api/fs/default-cwd', {'detail': 'no'}, status: status);
      final availability = await probed();
      expect(availability.support, FilesSupport.unsupported);
      expect(availability.shown, isFalse);
    });
  }

  for (final status in [200, 403, 500, 503]) {
    test('$status shows the entry points', () async {
      server.on('GET', '/api/fs/default-cwd', {'cwd': '/x'}, status: status);
      final availability = await probed();
      expect(availability.shown, isTrue);
    });
  }

  test('a probe that fails to complete shows them too', () async {
    final availability = FilesAvailability(
      () async => const FilesFailed(FilesFailure.unreachable),
    )..ensureProbed();
    addTearDown(availability.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(availability.shown, isTrue);
  });

  test('is asked once and sends no profile', () async {
    server.on('GET', '/api/fs/default-cwd', {'cwd': '/other-profile'});
    final availability = await probed();
    availability
      ..ensureProbed()
      ..ensureProbed();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final requests = server.requestsTo('GET', '/api/fs/default-cwd');
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters, isEmpty);
  });

  test('notifies once the answer is in', () async {
    server.on('GET', '/api/fs/default-cwd', {'cwd': '/x'});
    final availability = FilesAvailability.forRepositories(
      HermesRepositories(server.client()),
    );
    addTearDown(availability.dispose);
    var heard = 0;
    availability
      ..addListener(() => heard++)
      ..ensureProbed();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(heard, 1);
  });
}
