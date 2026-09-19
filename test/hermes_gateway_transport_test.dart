import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

/// Plays the dashboard's side of the socket: answers each RPC the way the
/// real gateway does and pushes the events a turn produces.
class FakeGateway {
  FakeGateway() {
    _wire.foreign.stream.listen(_onFrame, onDone: _closedByClient.complete);
  }

  final _closedByClient = Completer<void>();

  /// Completes when the app closed its end of the socket.
  Future<void> get closedByClient => _closedByClient.future;

  final _wire = StreamChannelController<String>();

  /// Every request received, in order.
  final requests = <Map<String, Object?>>[];

  StreamChannel<String> get channel => _wire.local;

  /// Runs after `prompt.submit` was answered; emits the turn's events.
  void Function(FakeGateway gateway, String sessionId) turn = (_, _) {};

  Map<String, Object?> createResult = {
    'session_id': 'rt-1',
    'stored_session_id': 'stored-1',
  };

  bool rejectSubmit = false;

  Object? resumeResult = {'session_id': 'rt-2', 'session_key': 'stored-2'};

  Iterable<String> get methods => requests.map((r) => r['method'] as String);

  Map<String, Object?> requestOf(String method) =>
      requests.firstWhere((r) => r['method'] == method);

  void event(
    String type,
    String sessionId, [
    Map<String, Object?> payload = const {},
  ]) => _send({
    'method': 'event',
    'params': {'type': type, 'session_id': sessionId, 'payload': payload},
  });

  void drop() => _wire.foreign.sink.close();

  void _send(Map<String, Object?> message) =>
      _wire.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', ...message}));

  void _onFrame(String frame) {
    final request = jsonDecode(frame) as Map<String, Object?>;
    requests.add(request);
    final id = request['id'];
    final params = request['params'] as Map<String, Object?>;
    switch (request['method']) {
      case 'session.create':
        _send({'id': id, 'result': createResult});
      case 'session.resume':
        final result = resumeResult;
        _send(
          result is Map
              ? {'id': id, 'result': result}
              : {
                  'id': id,
                  'error': {'code': 4007, 'message': 'session not found'},
                },
        );
      case 'prompt.submit' when rejectSubmit:
        _send({
          'id': id,
          'error': {'code': 4009, 'message': 'session busy'},
        });
      case 'prompt.submit':
        _send({
          'id': id,
          'result': {'status': 'streaming'},
        });
        turn(this, params['session_id'] as String);
    }
  }
}

void main() {
  late FakeGateway gateway;
  late int connects;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    connects = 0;
    transport = HermesGatewayTransport(
      connect: () async {
        connects++;
        return gateway.channel;
      },
    );
  });

  tearDown(() => transport.close());

  Future<List<ChatEvent>> reply({String? threadId, String text = 'hi'}) =>
      transport.send(threadId: threadId, text: text).toList();

  void plainReply(FakeGateway g, String sid) {
    g.event('message.start', sid);
    g.event('message.delta', sid, {'text': 'Hel'});
    g.event('message.delta', sid, {'text': 'lo'});
    g.event('message.complete', sid, {'text': 'Hello', 'status': 'complete'});
  }

  test('a new thread is created, bound and the reply streamed', () async {
    gateway.turn = plainReply;

    final events = await reply(text: 'hi');

    expect(events.map((e) => e.runtimeType), [
      ThreadBound,
      ReplyStarted,
      ReplyDelta,
      ReplyDelta,
      ReplyCompleted,
    ]);
    expect((events[0] as ThreadBound).threadId, 'stored-1');
    expect(
      [(events[2] as ReplyDelta).text, (events[3] as ReplyDelta).text],
      ['Hel', 'lo'],
    );
    final completed = events.last as ReplyCompleted;
    expect(completed.text, 'Hello');
    expect(completed.failed, isFalse);
  });

  test(
    'a new thread sends create, then submit on the runtime session',
    () async {
      gateway.turn = plainReply;

      await reply(text: 'hi');

      expect(gateway.methods, ['session.create', 'prompt.submit']);
      expect(gateway.requestOf('prompt.submit')['params'], {
        'session_id': 'rt-1',
        'text': 'hi',
      });
    },
  );

  test(
    'a stored thread is resumed and submitted to under the runtime id',
    () async {
      gateway.turn = plainReply;

      final events = await reply(threadId: 'stored-2', text: 'again');

      expect(gateway.methods, ['session.resume', 'prompt.submit']);
      expect(gateway.requestOf('session.resume')['params'], {
        'session_id': 'stored-2',
      });
      expect(gateway.requestOf('prompt.submit')['params'], {
        'session_id': 'rt-2',
        'text': 'again',
      });
      expect(events.whereType<ThreadBound>(), isEmpty);
      expect(events.last, isA<ReplyCompleted>());
    },
  );

  test('tool calls map to a started and a finished event', () async {
    gateway.turn = (g, sid) {
      g.event('message.start', sid);
      g.event('tool.start', sid, {
        'tool_id': 'call_1',
        'name': 'terminal',
        'context': 'ls -la',
        'args': {'command': 'ls -la'},
      });
      g.event('tool.complete', sid, {
        'tool_id': 'call_1',
        'name': 'terminal',
        'result': {'output': 'a\nb', 'exit_code': 0, 'error': null},
      });
      g.event('message.complete', sid, {'text': 'done', 'status': 'complete'});
    };

    final events = await reply();

    final started = events.whereType<ToolStarted>().single;
    expect(started.name, 'terminal');
    expect(started.summary, 'ls -la');
    final finished = events.whereType<ToolFinished>().single;
    expect(finished.name, 'terminal');
    expect(finished.failed, isFalse);
  });

  test('a tool result carrying an error is a failed tool', () async {
    gateway.turn = (g, sid) {
      g.event('tool.complete', sid, {
        'name': 'terminal',
        'result': {'output': '', 'exit_code': -1, 'error': 'timed out'},
      });
      g.event('message.complete', sid, {'text': 'x', 'status': 'complete'});
    };

    final events = await reply();

    expect(events.whereType<ToolFinished>().single.failed, isTrue);
  });

  test('the dashboard\'s title for the thread is forwarded', () async {
    gateway.turn = (g, sid) {
      g.event('session.title', sid, {
        'session_id': 'stored-1',
        'title': 'Greeting',
      });
      g.event('message.complete', sid, {'text': 'x', 'status': 'complete'});
    };

    final events = await reply();

    expect(events.whereType<ThreadTitled>().single.title, 'Greeting');
  });

  test('a turn that ends in error completes as failed', () async {
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'provider unavailable',
      'status': 'error',
    });

    final events = await reply();

    final completed = events.last as ReplyCompleted;
    expect(completed.failed, isTrue);
    expect(completed.text, 'provider unavailable');
  });

  test('events of other sessions and unmodelled events are dropped', () async {
    gateway.turn = (g, sid) {
      g.event('sessions.changed', '');
      g.event('message.delta', 'someone-else', {'text': 'not mine'});
      g.event('session.info', sid, {'model': 'm'});
      g.event('thinking.delta', sid, {'text': '( •_•) analyzing...'});
      g.event('reasoning.delta', sid, {'text': 'hmm'});
      g.event('message.delta', sid, {'text': 'mine'});
      g.event('message.complete', 'someone-else', {'text': 'not mine'});
      g.event('message.complete', sid, {'text': 'mine', 'status': 'complete'});
    };

    final events = await reply();

    expect(events.map((e) => e.runtimeType), [
      ThreadBound,
      ReplyDelta,
      ReplyCompleted,
    ]);
    expect((events[1] as ReplyDelta).text, 'mine');
  });

  test('nothing connects until the reply is listened to', () async {
    final stream = transport.send(text: 'hi');
    await pumpEventQueue();

    expect(connects, 0);

    gateway.turn = plainReply;
    await stream.toList();

    expect(connects, 1);
  });

  test('the connection is reused across sends', () async {
    gateway.turn = plainReply;

    await reply(text: 'one');
    await reply(text: 'two');

    expect(connects, 1);
    expect(gateway.methods, [
      'session.create',
      'prompt.submit',
      'session.create',
      'prompt.submit',
    ]);
  });

  test('a send after the socket dropped opens a new connection', () async {
    final second = FakeGateway()..turn = plainReply;
    final gateways = [gateway, second];
    transport = HermesGatewayTransport(
      connect: () async => gateways[connects++].channel,
    );
    gateway.turn = plainReply;
    await reply();
    gateway.drop();
    await pumpEventQueue();

    await reply();

    expect(connects, 2);
    expect(second.methods, ['session.create', 'prompt.submit']);
  });

  test('a failed connection attempt is retried by the next send', () async {
    var attempts = 0;
    transport = HermesGatewayTransport(
      connect: () async {
        if (attempts++ == 0) throw StateError('unreachable');
        return gateway.channel;
      },
    );
    gateway.turn = plainReply;

    await expectLater(reply(), throwsStateError);
    final events = await reply();

    expect(events.last, isA<ReplyCompleted>());
  });

  test('the socket dropping mid-reply fails the stream', () async {
    gateway.turn = (g, sid) {
      g.event('message.start', sid);
      g.event('message.delta', sid, {'text': 'Hel'});
      g.drop();
    };
    final seen = <ChatEvent>[];

    await expectLater(
      transport.send(text: 'hi').forEach(seen.add),
      throwsA(isA<GatewayConnectionClosed>()),
    );

    expect(seen.last, isA<ReplyDelta>());
  });

  test('an error from the gateway fails the stream', () async {
    gateway.resumeResult = null;

    await expectLater(
      reply(threadId: 'gone'),
      throwsA(isA<GatewayRpcException>()),
    );
  });

  test('a rejected prompt fails the stream instead of hanging', () async {
    gateway.rejectSubmit = true;

    await expectLater(
      reply().timeout(const Duration(seconds: 2)),
      throwsA(isA<GatewayRpcException>()),
    );
  });

  test('cancelling right after the thread is bound ends cleanly', () async {
    gateway.turn = plainReply;
    final bound = Completer<void>();
    final subscription = transport.send(text: 'hi').listen((event) {
      if (event is ThreadBound) bound.complete();
    });
    await bound.future;

    await subscription.cancel().timeout(const Duration(seconds: 2));
  });

  test('closing the transport closes the socket', () async {
    gateway.turn = plainReply;
    await reply();

    await transport.close();

    await expectLater(gateway.closedByClient, completes);
  });
}
