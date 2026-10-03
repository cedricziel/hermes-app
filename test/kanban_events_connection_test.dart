import 'dart:convert';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_events_connection.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/recording_tracer.dart';

const _page = '<script>window.__HERMES_SESSION_TOKEN__="tok-123";</script>';

void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late List<Uri> opened;
  late StreamChannelController<String> socket;

  setUp(() {
    server = FakeHermesServer()..on('GET', '/', _page);
    tracer = RecordingTracer();
    opened = [];
    socket = StreamChannelController<String>();
  });

  Future<StreamChannel<String>> connect({
    Tracer? tracedBy,
    bool traced = true,
  }) => hermesKanbanEventsConnect(
    baseUrl: 'http://hermes.test',
    authRequired: false,
    api: server.client(),
    telemetry: traced ? KanbanEventsTracer(tracedBy ?? tracer) : null,
    open: (uri) async {
      opened.add(uri);
      return socket.foreign;
    },
  )(since: 4, board: 'ops');

  Iterable<RecordingSpan> consumerSpans() =>
      tracer.spans.where((s) => s.kind == SpanKind.consumer);

  test('opens the events route from the cursor, for the board', () async {
    await connect();

    expect(
      opened.single.toString(),
      'ws://hermes.test/api/plugins/kanban/events'
      '?since=4&board=ops&token=tok-123',
    );
  });

  test('without telemetry the socket is handed over as it is', () async {
    expect(await connect(traced: false), same(socket.foreign));
    expect(tracer.spans, isEmpty);
  });

  test('the upgrade is an HTTP GET span on the events route', () async {
    await connect();

    final span = tracer.spans.single;
    expect(span.name, 'HTTP GET');
    expect(span.kind, SpanKind.client);
    expect(span.attributes['http.route'], '/api/plugins/kanban/events');
    expect(span.status, StatusCode.ok);
  });

  test('each event is a consumer span named by its kind alone', () async {
    final channel = await connect();
    final frames = <String>[];
    channel.stream.listen(frames.add);
    final frame = jsonEncode({
      'cursor': 9,
      'events': [
        {
          'id': 8,
          'task_id': 't_secret',
          'kind': 'blocked',
          'payload': {'reason': 'secret reason'},
        },
        {'id': 9, 'task_id': 't_secret', 'kind': 'something_new'},
        {'id': 10, 'task_id': 't_secret', 'kind': 'heartbeat'},
      ],
    });

    socket.local.sink.add(frame);
    await pumpEventQueue();

    expect(frames, [frame]);
    expect(consumerSpans().map((s) => s.name), [
      'blocked receive',
      'other receive',
    ]);
    expect(
      consumerSpans().first.attributes['messaging.system'],
      'hermes.kanban',
    );
    for (final span in tracer.spans) {
      final values = span.attributes.values.join(' ');
      expect(values, isNot(contains('secret')));
      expect(values, isNot(contains('ops')));
    }
  });

  test('a frame that is not an event list is passed on untraced', () async {
    final channel = await connect();
    final frames = <String>[];
    channel.stream.listen(frames.add);

    socket.local.sink
      ..add('not json')
      ..add('[1, 2]')
      ..add('{"cursor": 1, "events": [{"kind": 3}, "x"]}');
    await pumpEventQueue();

    expect(frames, hasLength(3));
    expect(consumerSpans(), isEmpty);
  });

  test('a tracer that throws does not break the stream', () async {
    final channel = await connect(tracedBy: ThrowingTracer());
    final frames = <String>[];
    channel.stream.listen(frames.add);

    socket.local.sink.add('{"cursor": 1, "events": [{"kind": "created"}]}');
    await pumpEventQueue();

    expect(frames, hasLength(1));
  });
}
