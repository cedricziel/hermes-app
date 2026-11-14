import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/tools_availability.dart';

import '../support/fake_hermes_server.dart';
import 'tools_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late ToolsAvailability availability;
  late List<String> events;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/tools/toolsets', toolsetsFixture);
    events = [];
    availability = ToolsAvailability(
      toolsRepository(server),
      telemetry: ConnectionTelemetry(
        events: (name, [attributes = const {}]) =>
            events.add('$name $attributes'),
      ),
    );
  });

  tearDown(() => availability.dispose());

  test('a read offers Tools and hands the rows to that profile only', () async {
    final read = await availability.refresh('work');

    expect(read, ToolsAvailabilityRead.ok);
    expect(availability.offered, isTrue);
    expect(availability.rowsFor('work').map((t) => t.name), [
      'web',
      'terminal',
    ]);
    expect(availability.rowsFor('home'), isEmpty);
    expect(availability.enabledCount('work'), 1);
    expect(availability.enabledCount('home'), isNull);
    expect(
      server.requestsTo('GET', '/api/tools/toolsets').single.queryParameters,
      containsPair('profile', 'work'),
    );
    expect(events, ['tools.availability {outcome: ok}']);
  });

  test('404 hides Tools without a message', () async {
    server.on('GET', '/api/tools/toolsets', {
      'detail': 'Not Found',
    }, status: 404);

    final read = await availability.refresh('work');

    expect(read, ToolsAvailabilityRead.unsupported);
    expect(availability.offered, isFalse);
    expect(availability.profileGone, isFalse);
    expect(events.single, contains('unsupported'));
  });

  test('405 hides Tools and forgets earlier rows', () async {
    await availability.refresh('work');
    server.on('GET', '/api/tools/toolsets', {'detail': 'x'}, status: 405);

    await availability.refresh('work');

    expect(availability.offered, isFalse);
    expect(availability.rowsFor('work'), isEmpty);
  });

  test('a failed read keeps the previous answer', () async {
    await availability.refresh('work');
    server.on('GET', '/api/tools/toolsets', {'detail': 'boom'}, status: 503);

    final read = await availability.refresh('work');

    expect(read, ToolsAvailabilityRead.unreachable);
    expect(availability.offered, isTrue);
    expect(availability.rowsFor('work'), hasLength(2));
    expect(events.last, 'tools.availability {outcome: unreachable}');
  });

  test(
    'a network failure with no earlier answer leaves Tools hidden',
    () async {
      server.onRequest('GET', '/api/tools/toolsets', (r) {
        throw DioException.connectionError(
          requestOptions: r,
          reason: 'offline',
        );
      });

      final read = await availability.refresh('work');

      expect(read, ToolsAvailabilityRead.unreachable);
      expect(availability.offered, isFalse);
    },
  );

  test('a resume reads again and takes the new rows', () async {
    await availability.refresh('work');
    server.on('GET', '/api/tools/toolsets', [toolsetsFixture.first]);

    await availability.refresh('work');

    expect(availability.rowsFor('work'), hasLength(1));
    expect(server.requestsTo('GET', '/api/tools/toolsets'), hasLength(2));
  });

  test('a late answer for a profile that changed is dropped', () async {
    final gate = Completer<void>();
    server.onRequest('GET', '/api/tools/toolsets', (r) async {
      if (r.queryParameters['profile'] == 'work') await gate.future;
      return (status: 200, body: toolsetsFixture);
    });
    final first = availability.refresh('work');
    final second = await availability.refresh('home');
    gate.complete();

    expect(await first, ToolsAvailabilityRead.dropped);
    expect(second, ToolsAvailabilityRead.ok);
    expect(availability.rowsFor('home'), hasLength(2));
    expect(availability.rowsFor('work'), isEmpty);
  });

  test('a profile that is gone is not "unsupported"', () async {
    await availability.refresh('work');
    server.on('GET', '/api/tools/toolsets', {
      'detail': "Profile 'work' does not exist",
    }, status: 404);

    final read = await availability.refresh('work');

    expect(read, ToolsAvailabilityRead.profileGone);
    expect(availability.profileGone, isTrue);
    expect(availability.offered, isTrue);
    expect(availability.rowsFor('work'), hasLength(2));
    expect(events.last, isNot(contains('unsupported')));
  });

  test('clear forgets the answer and drops a read still on its way', () async {
    final gate = Completer<void>();
    server.onRequest('GET', '/api/tools/toolsets', (r) async {
      await gate.future;
      return (status: 200, body: toolsetsFixture);
    });
    final pending = availability.refresh('work');
    availability.clear();
    gate.complete();

    expect(await pending, ToolsAvailabilityRead.dropped);
    expect(availability.offered, isFalse);
    expect(availability.rowsFor('work'), isEmpty);
  });

  test('nothing in the log names the profile or a toolset', () async {
    await availability.refresh('work');

    expect(events.join(), isNot(contains('work')));
    expect(events.join(), isNot(contains('terminal')));
  });
}
