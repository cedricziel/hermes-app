import 'dart:async';
import 'dart:convert';
import 'dart:io' show FileSystemException;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart'
    show AttachmentKind, UnsupportedKind;
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:stream_channel/stream_channel.dart';

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

  /// Every response frame the app sent to a server-to-client request.
  final responses = <Map<String, Object?>>[];

  StreamChannel<String> get channel => _wire.local;

  /// Runs after `prompt.submit` was answered; emits the turn's events.
  void Function(FakeGateway gateway, String sessionId) turn = (_, _) {};

  Map<String, Object?> createResult = {
    'session_id': 'rt-1',
    'stored_session_id': 'stored-1',
  };

  bool rejectSubmit = false;

  /// Requests the gateway never answers, as a socket the OS dropped while the
  /// app slept does not.
  final silent = <String>{};

  /// Every request goes unanswered.
  bool deaf = false;

  /// The runtime session of the latest `prompt.submit`.
  String lastSessionId = '';

  /// When set, `session.create` and `session.resume` fail with this JSON-RPC
  /// error code, as a gateway does for a profile that no longer exists.
  int? sessionErrorCode;

  /// How many approvals `approval.respond` reports resolved.
  int approvalsResolved = 1;

  /// The `status` `clarify.respond` reports.
  String clarifyStatus = 'ok';

  /// The `status` `clarify.lock` reports.
  String lockStatus = 'ok';

  /// The `status` `sudo.respond` and `secret.respond` report.
  String skipStatus = 'ok';

  /// The `status` `session.interrupt` reports.
  String interruptStatus = 'interrupted';

  /// Whether `client.capabilities` fails, as it does on a gateway that
  /// predates server-to-client requests.
  bool capabilitiesUnknown = false;

  /// Attach methods the gateway does not know, as a gateway that predates
  /// them answers.
  final unknownMethods = <String>{};

  /// Attach calls that fail, by `<method> <file name>`: the JSON-RPC error
  /// code and message to answer with.
  final attachFailures = <String, (int, String)>{};

  /// The image paths the gateway queued for the next prompt, as `image.detach`
  /// leaves them.
  final queuedImages = <String>[];

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

  /// Sends a server-to-client request, the way the gateway asks the client a
  /// question and waits for the response frame carrying the same [id].
  void serverRequest(
    String id,
    String method,
    String sessionId, [
    Map<String, Object?> params = const {},
  ]) => _send({
    'id': id,
    'method': method,
    'params': {'session_id': sessionId, ...params},
  });

  void drop() => _wire.foreign.sink.close();

  void _send(Map<String, Object?> message) =>
      _wire.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', ...message}));

  void _onFrame(String frame) {
    final request = jsonDecode(frame) as Map<String, Object?>;
    if (!request.containsKey('method')) {
      responses.add(request);
      return;
    }
    requests.add(request);
    if (deaf || silent.contains(request['method'])) return;
    final id = request['id'];
    final params = request['params'] as Map<String, Object?>;
    switch (request['method']) {
      case 'session.create' || 'session.resume' when sessionErrorCode != null:
        _send({
          'id': id,
          'error': {
            'code': sessionErrorCode,
            'message': "profile 'gone' not found",
          },
        });
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
      case 'client.capabilities' when capabilitiesUnknown:
        _send({
          'id': id,
          'error': {'code': -32601, 'message': 'unknown method'},
        });
      case 'client.capabilities':
        _send({
          'id': id,
          'result': {
            'server_requests': ['approval', 'clarify', 'sudo', 'secret'],
          },
        });
      case 'config.set':
        _send({
          'id': id,
          'result': {'key': params['key'], 'value': params['value']},
        });
      case 'session.interrupt':
        _send({
          'id': id,
          'result': {'status': interruptStatus},
        });
      case 'sudo.respond' || 'secret.respond':
        _send({
          'id': id,
          'result': {'status': skipStatus},
        });
      case 'clarify.lock':
        _send({
          'id': id,
          'result': {'status': lockStatus, 'remaining': <String>[]},
        });
      case 'approval.respond':
        _send({
          'id': id,
          'result': {'resolved': approvalsResolved},
        });
      case 'clarify.respond':
        _send({
          'id': id,
          'result': {'status': clarifyStatus},
        });
      case 'image.attach_bytes' || 'file.attach' || 'image.detach'
          when unknownMethods.contains(request['method']):
        _send({
          'id': id,
          'error': {'code': -32601, 'message': 'unknown method'},
        });
      case 'image.attach_bytes' || 'file.attach'
          when attachFailures.containsKey(
            '${request['method']} ${params['filename'] ?? params['name']}',
          ):
        final (code, message) =
            attachFailures['${request['method']} ${params['filename'] ?? params['name']}']!;
        _send({
          'id': id,
          'error': {'code': code, 'message': message},
        });
      case 'image.attach_bytes':
        final path =
            '/home/u/.hermes/images/upload_${queuedImages.length + 1}.png';
        queuedImages.add(path);
        _send({
          'id': id,
          'result': {
            'attached': true,
            'path': path,
            'count': queuedImages.length,
            'remainder': '',
            'text': '[User attached image: upload.png]',
          },
        });
      case 'file.attach':
        final name = params['name'] as String;
        _send({
          'id': id,
          'result': {
            'attached': true,
            'name': name,
            'path': '/home/u/.hermes/attachments/$name',
            'ref_path': 'attachments/$name',
            'ref_text': '@file:attachments/$name',
            'uploaded': true,
          },
        });
      case 'image.detach':
        queuedImages.remove(params['path']);
        _send({
          'id': id,
          'result': {'detached': true, 'count': queuedImages.length},
        });
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
        lastSessionId = params['session_id'] as String;
        turn(this, lastSessionId);
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

  Future<List<ChatEvent>> reply({
    String? threadId,
    String? profile,
    String text = 'hi',
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
  }) => transport
      .send(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: model,
      )
      .toList();

  /// Runs a turn that [raise]s an approval or clarify request, calls [answer]
  /// on the transport while the turn waits, then completes the turn.
  Future<T> answerWhileRaising<T>(
    void Function(FakeGateway gateway, String sessionId) raise,
    Future<T> Function() answer,
  ) async {
    gateway.turn = raise;
    final done = Completer<void>();
    late T result;
    transport.send(text: 'hi').listen((e) async {
      if (e is ApprovalRequested ||
          e is ClarifyRequested ||
          e is UnsupportedRequested) {
        result = await answer();
        gateway.event('message.complete', 'rt-1', {
          'text': 'ok',
          'status': 'complete',
        });
      }
    }, onDone: done.complete);
    await done.future;
    return result;
  }

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

      expect(gateway.methods, [
        'client.capabilities',
        'session.create',
        'prompt.submit',
      ]);
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

      expect(gateway.methods, [
        'client.capabilities',
        'session.resume',
        'prompt.submit',
      ]);
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

  group('model choice', () {
    const opus = ModelChoice('anthropic', 'claude-opus-4', effort: 'high');

    List<Map<String, Object?>> configSets() => [
      for (final r in gateway.requests)
        if (r['method'] == 'config.set') r['params'] as Map<String, Object?>,
    ];

    test('a new thread is created with the chosen model and effort', () async {
      gateway.turn = plainReply;

      await reply(profile: 'work', model: opus);

      expect(gateway.requestOf('session.create')['params'], {
        'profile': 'work',
        'model': 'claude-opus-4',
        'provider': 'anthropic',
        'reasoning_effort': 'high',
      });
      expect(configSets(), isEmpty);
    });

    test('a new thread without an effort leaves it to the server', () async {
      gateway.turn = plainReply;

      await reply(model: const ModelChoice('openai', 'gpt-5.1'));

      expect(gateway.requestOf('session.create')['params'], {
        'model': 'gpt-5.1',
        'provider': 'openai',
      });
    });

    test(
      'a resumed thread switches model and effort before the prompt',
      () async {
        gateway.turn = plainReply;

        await reply(threadId: 'stored-2', model: opus);

        expect(gateway.methods, [
          'client.capabilities',
          'session.resume',
          'config.set',
          'config.set',
          'prompt.submit',
        ]);
        expect(configSets(), [
          {
            'session_id': 'rt-2',
            'key': 'model',
            'value': 'claude-opus-4 --provider anthropic',
            'confirm_expensive_model': true,
          },
          {'session_id': 'rt-2', 'key': 'reasoning', 'value': 'high'},
        ]);
      },
    );

    test('a thread is not switched again to the choice it runs', () async {
      gateway.turn = plainReply;

      await reply(model: opus);
      await reply(threadId: 'stored-1', model: opus);
      await reply(threadId: 'stored-2', model: opus);
      await reply(threadId: 'stored-2', model: opus);

      expect(configSets(), hasLength(2));
    });

    test('only the effort is sent when only the effort changed', () async {
      gateway.turn = plainReply;

      await reply(model: opus);
      await reply(
        threadId: 'stored-1',
        model: const ModelChoice('anthropic', 'claude-opus-4', effort: 'low'),
      );

      expect(configSets(), [
        {'session_id': 'rt-2', 'key': 'reasoning', 'value': 'low'},
      ]);
    });

    test('a resumed thread without a choice is left as it is', () async {
      gateway.turn = plainReply;

      await reply(threadId: 'stored-2');

      expect(configSets(), isEmpty);
    });
  });

  test('a new thread is created in the given profile', () async {
    gateway.turn = plainReply;

    await reply(profile: 'work');

    expect(gateway.requestOf('session.create')['params'], {'profile': 'work'});
    expect(gateway.requestOf('prompt.submit')['params'], {
      'session_id': 'rt-1',
      'text': 'hi',
    });
  });

  test('a stored thread is resumed in the given profile', () async {
    gateway.turn = plainReply;

    await reply(threadId: 'stored-2', profile: 'work');

    expect(gateway.requestOf('session.resume')['params'], {
      'session_id': 'stored-2',
      'profile': 'work',
    });
  });

  test('a session is created and resumed unscoped without a profile', () async {
    gateway.turn = plainReply;

    await reply();
    await reply(threadId: 'stored-2');

    expect(gateway.requestOf('session.create')['params'], isEmpty);
    expect(gateway.requestOf('session.resume')['params'], {
      'session_id': 'stored-2',
    });
  });

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
    expect(finished.result, 'a\nb');
  });

  test('reasoning events map to reasoning updates', () async {
    gateway.turn = (g, sid) {
      g.event('message.start', sid);
      g.event('reasoning.delta', sid, {'text': 'Hmm, '});
      g.event('reasoning.delta', sid, {'text': 'ok.'});
      g.event('reasoning.available', sid, {'text': 'Hmm, ok.'});
      g.event('message.complete', sid, {'text': 'done', 'status': 'complete'});
    };

    final events = await reply();

    final updates = events.whereType<ReasoningUpdated>().toList();
    expect(updates.map((e) => (e.text, e.replace)), [
      ('Hmm, ', false),
      ('ok.', false),
      ('Hmm, ok.', true),
    ]);
  });

  test('an interim event maps to a checkpoint', () async {
    gateway.turn = (g, sid) {
      g.event('message.start', sid);
      g.event('message.delta', sid, {'text': 'Hey!'});
      g.event('message.interim', sid, {
        'text': 'Hey!',
        'already_streamed': true,
      });
      g.event('message.complete', sid, {'text': '', 'status': 'complete'});
    };

    final events = await reply();

    final checkpoint = events.whereType<ReplyCheckpoint>().single;
    expect(checkpoint.text, 'Hey!');
    expect(checkpoint.alreadyStreamed, isTrue);
  });

  test('an interim event missing the flag counts as not streamed', () async {
    gateway.turn = (g, sid) {
      g.event('message.start', sid);
      g.event('message.interim', sid, {'text': 'Aside.'});
      g.event('message.complete', sid, {'text': '', 'status': 'complete'});
    };

    final events = await reply();

    expect(events.whereType<ReplyCheckpoint>().single.alreadyStreamed, isFalse);
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
      'client.capabilities',
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
    expect(second.methods, [
      'client.capabilities',
      'session.create',
      'prompt.submit',
    ]);
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

  group('a profile that no longer exists', () {
    setUp(() => gateway.sessionErrorCode = 4064);

    test('fails a new thread with ProfileUnavailableException', () async {
      await expectLater(
        reply(profile: 'gone'),
        throwsA(isA<ProfileUnavailableException>()),
      );

      expect(gateway.methods, isNot(contains('prompt.submit')));
    });

    test('fails a resumed thread with ProfileUnavailableException', () async {
      await expectLater(
        reply(threadId: 'stored-2', profile: 'gone'),
        throwsA(isA<ProfileUnavailableException>()),
      );

      expect(gateway.methods, isNot(contains('prompt.submit')));
    });

    test('is not retried and keeps the connection usable', () async {
      await expectLater(
        reply(profile: 'gone'),
        throwsA(isA<ProfileUnavailableException>()),
      );
      gateway.sessionErrorCode = null;
      gateway.turn = plainReply;

      final events = await reply(profile: 'work');

      expect(events.last, isA<ReplyCompleted>());
      expect(gateway.methods.where((m) => m == 'session.create'), hasLength(2));
      expect(connects, 1);
    });

    test('does not leak the gateway message', () async {
      final error = await reply(profile: 'gone')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error.toString(), isNot(contains('gone')));
    });

    test('another error code stays a GatewayRpcException', () async {
      gateway.sessionErrorCode = 4007;

      await expectLater(
        reply(profile: 'gone'),
        throwsA(isA<GatewayRpcException>()),
      );
    });
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

  group('agent input requests', () {
    const approvalPayload = {
      'request_id': 'r1',
      'command': 'rm -rf build',
      'description': 'delete files',
      'choices': ['once', 'session', 'deny'],
    };

    test('an approval request becomes an event', () async {
      gateway.turn = (g, sid) {
        g.event('approval.request', sid, approvalPayload);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ApprovalRequested>().single.request;
      expect(request.requestId, 'r1');
      expect(request.command, 'rm -rf build');
      expect(request.description, 'delete files');
      expect(request.choices, ['once', 'session', 'deny']);
    });

    for (final (label, choices) in <(String, Object?)>[
      ('absent', null),
      ('empty', <String>[]),
      ('malformed', 'once'),
    ]) {
      test('an approval with $label choices still becomes an event, and the '
          'card falls back to its own buttons', () async {
        final payload = {...approvalPayload}..remove('choices');
        if (choices != null) payload['choices'] = choices;
        gateway.turn = (g, sid) {
          g.event('approval.request', sid, payload);
          g.event('message.complete', sid, {
            'text': 'ok',
            'status': 'complete',
          });
        };

        final events = await reply();

        final request = events.whereType<ApprovalRequested>().single.request;
        expect(request.requestId, 'r1');
        expect(request.command, 'rm -rf build');
        expect(request.choices, isEmpty);
      });
    }

    test('an approval without choices can be answered once', () async {
      final payload = {...approvalPayload}..remove('choices');

      final accepted = await answerWhileRaising(
        (g, sid) => g.event('approval.request', sid, payload),
        () => transport.answerApproval('r1', 'once'),
      );

      expect(accepted, isTrue);
      expect(gateway.requestOf('approval.respond')['params'], {
        'session_id': 'rt-1',
        'request_id': 'r1',
        'choice': 'once',
      });
    });

    test('a single clarify question becomes a one-question request', () async {
      gateway.turn = (g, sid) {
        g.event('clarify.request', sid, {
          'request_id': 'r2',
          'question': 'Which colour?',
          'choices': ['red', 'blue'],
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ClarifyRequested>().single.request;
      expect(request.batch, isFalse);
      expect(request.questions.single.qid, '');
      expect(request.questions.single.question, 'Which colour?');
      expect(request.questions.single.choices, ['red', 'blue']);
      expect(request.questions.single.multiSelect, isFalse);
    });

    test('an open-ended multi-select batch keeps each question', () async {
      gateway.turn = (g, sid) {
        g.event('clarify.request', sid, {
          'request_id': 'r3',
          'questions': [
            {
              'qid': 'a',
              'question': 'Name?',
              'choices': null,
              'multi_select': false,
            },
            {
              'qid': 'b',
              'question': 'Toppings?',
              'choices': ['ham', 'olives'],
              'multi_select': true,
            },
          ],
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ClarifyRequested>().single.request;
      expect(request.batch, isTrue);
      expect(request.questions.map((q) => q.qid), ['a', 'b']);
      expect(request.questions[0].choices, isEmpty);
      expect(request.questions[1].multiSelect, isTrue);
    });

    test('an expire event becomes InputRequestExpired', () async {
      gateway.turn = (g, sid) {
        g.event('clarify.expire', sid, {'request_id': 'r2'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.whereType<InputRequestExpired>().single.requestId, 'r2');
    });

    test('a secret request becomes an unsupported request', () async {
      gateway.turn = (g, sid) {
        g.event('secret.request', sid, {
          'request_id': 'r5',
          'prompt': 'Enter the key',
          'env_var': 'SERVICE_API_KEY',
          'metadata': {'service': 'example'},
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<UnsupportedRequested>().single.request;
      expect(request.requestId, 'r5');
      expect(request.kind, UnsupportedKind.secret);
    });

    test('a sudo request becomes an unsupported request', () async {
      gateway.turn = (g, sid) {
        g.event('sudo.request', sid, {'request_id': 'r6'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<UnsupportedRequested>().single.request;
      expect(request.requestId, 'r6');
      expect(request.kind, UnsupportedKind.sudo);
    });

    test('nothing is sent for a secret or sudo request', () async {
      gateway.turn = (g, sid) {
        g.event('secret.request', sid, {'request_id': 'r5'});
        g.event('sudo.request', sid, {'request_id': 'r6'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      await reply();

      expect(gateway.methods, [
        'client.capabilities',
        'session.create',
        'prompt.submit',
      ]);
    });

    test('secret and sudo expire events end the request', () async {
      gateway.turn = (g, sid) {
        g.event('secret.expire', sid, {'request_id': 'r5'});
        g.event('sudo.expire', sid, {'request_id': 'r6'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.whereType<InputRequestExpired>().map((e) => e.requestId), [
        'r5',
        'r6',
      ]);
    });

    /// Runs a turn that raises [payload] as [event], calls [answer] on the
    /// transport while the turn waits, then completes the turn.
    Future<T> answerWhileWaiting<T>(
      String event,
      Map<String, Object?> payload,
      Future<T> Function() answer,
    ) => answerWhileRaising((g, sid) => g.event(event, sid, payload), answer);

    test('an approval is answered on the runtime session', () async {
      final accepted = await answerWhileWaiting(
        'approval.request',
        approvalPayload,
        () => transport.answerApproval('r1', 'once'),
      );

      expect(accepted, isTrue);
      expect(gateway.requestOf('approval.respond')['params'], {
        'session_id': 'rt-1',
        'request_id': 'r1',
        'choice': 'once',
      });
    });

    test('an approval nothing is waiting on reports not accepted', () async {
      gateway.approvalsResolved = 0;

      final accepted = await answerWhileWaiting(
        'approval.request',
        approvalPayload,
        () => transport.answerApproval('r1', 'once'),
      );

      expect(accepted, isFalse);
    });

    test('an approval answered after its turn ended sends nothing', () async {
      gateway.turn = (g, sid) {
        g.event('approval.request', sid, approvalPayload);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };
      await reply();

      expect(await transport.answerApproval('r1', 'once'), isFalse);
      expect(gateway.methods, isNot(contains('approval.respond')));
    });

    test('a turn ending keeps the requests of a turn still open', () async {
      Map<String, Object?> approval(String id) => {
        ...approvalPayload,
        'request_id': id,
      };
      final sawFirst = Completer<void>();
      final sawSecond = Completer<void>();
      late final StreamSubscription<ChatEvent> first;
      first = transport.send(threadId: 'stored-2', text: 'a').listen((e) {
        if (e is ApprovalRequested && !sawFirst.isCompleted) {
          first.pause();
          sawFirst.complete();
        }
      });
      transport.send(threadId: 'stored-2', text: 'b').listen((e) {
        if (e is ApprovalRequested && e.request.requestId == 'r2') {
          sawSecond.complete();
        }
      }, onError: (_) {}); // the still-open turn ends with the teardown
      while (gateway.methods.where((m) => m == 'prompt.submit').length < 2) {
        await Future<void>.delayed(Duration.zero);
      }

      // Both turns share the runtime session; the first has taken r1 and is
      // paused, so r2 reaches only the second turn's registrations.
      gateway.event('approval.request', 'rt-2', approval('r1'));
      await sawFirst.future;
      gateway.event('approval.request', 'rt-2', approval('r2'));
      await sawSecond.future;
      await first.cancel();

      expect(await transport.answerApproval('r2', 'once'), isTrue);
      expect(gateway.requestOf('approval.respond')['params'], {
        'session_id': 'rt-2',
        'request_id': 'r2',
        'choice': 'once',
      });
    });

    test('an approval for an unknown request sends nothing', () async {
      expect(await transport.answerApproval('nope', 'once'), isFalse);
      expect(gateway.requests, isEmpty);
    });

    test('a clarify answer carries the request id and no session', () async {
      final accepted = await answerWhileWaiting('clarify.request', {
        'request_id': 'r2',
        'question': 'Which colour?',
      }, () => transport.answerClarify('r2', ['blue']));

      expect(accepted, isTrue);
      expect(gateway.requestOf('clarify.respond')['params'], {
        'request_id': 'r2',
        'answer': 'blue',
      });
    });

    test('a batch answer names its question', () async {
      await answerWhileWaiting('clarify.request', {
        'request_id': 'r3',
        'questions': <Object?>[],
      }, () => transport.answerClarify('r3', ['ham'], questionId: 'b'));

      expect(
        (gateway.requestOf('clarify.respond')['params'] as Map)['question_id'],
        'b',
      );
    });

    test('a multi-select answer is a JSON array in a string', () async {
      await answerWhileWaiting(
        'clarify.request',
        {'request_id': 'r2', 'question': 'Toppings?', 'multi_select': true},
        () =>
            transport.answerClarify('r2', ['ham', 'olives'], multiSelect: true),
      );

      expect(
        (gateway.requestOf('clarify.respond')['params'] as Map)['answer'],
        '["ham","olives"]',
      );
    });

    test('skipping sends an empty answer', () async {
      await answerWhileWaiting('clarify.request', {
        'request_id': 'r2',
        'question': 'Which colour?',
      }, () => transport.answerClarify('r2', const []));

      expect(
        (gateway.requestOf('clarify.respond')['params'] as Map)['answer'],
        '',
      );
    });

    test('an expired clarify request reports not accepted', () async {
      gateway.clarifyStatus = 'expired';

      final accepted = await answerWhileWaiting('clarify.request', {
        'request_id': 'r2',
        'question': 'Which colour?',
      }, () => transport.answerClarify('r2', ['blue']));

      expect(accepted, isFalse);
    });
  });

  group('server-to-client requests', () {
    const approvalParams = {
      'request_id': 'q1',
      'command': 'rm -rf build',
      'description': 'delete files',
      'choices': ['once', 'session', 'deny'],
    };

    /// Runs a turn that raises [method] as a server-to-client request with
    /// the id [id], calls [answer] while the turn waits, then completes it.
    Future<T> answerWhileWaiting<T>(
      String id,
      String method,
      Map<String, Object?> params,
      Future<T> Function() answer,
    ) => answerWhileRaising(
      (g, sid) => g.serverRequest(id, method, sid, params),
      answer,
    );

    test('the capability is announced before any session call', () async {
      gateway.turn = plainReply;

      await reply();

      expect(gateway.requests.first['method'], 'client.capabilities');
      expect(gateway.requests.first['params'], {'server_requests': true});
    });

    test('a gateway without the capability call still works', () async {
      gateway.capabilitiesUnknown = true;
      gateway.turn = plainReply;

      final events = await reply();

      expect(events.last, isA<ReplyCompleted>());
    });

    test('the capability is announced again on a new connection', () async {
      gateway.turn = plainReply;
      await reply();
      gateway.drop();
      await pumpEventQueue();
      final second = FakeGateway()..turn = plainReply;
      transport = HermesGatewayTransport(connect: () async => second.channel);

      await reply();

      expect(second.methods.first, 'client.capabilities');
    });

    test('an approval request becomes an approval, keyed by its id', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-1', 'approval', sid, approvalParams);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ApprovalRequested>().single.request;
      expect(request.requestId, 'srq-1');
      expect(request.command, 'rm -rf build');
      expect(request.description, 'delete files');
      expect(request.choices, ['once', 'session', 'deny']);
    });

    test('a server-request approval without choices has none', () async {
      final params = {...approvalParams}..remove('choices');
      gateway.turn = (g, sid) {
        g.serverRequest('srq-1', 'approval', sid, params);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(
        events.whereType<ApprovalRequested>().single.request.choices,
        isEmpty,
      );
    });

    test('an approval is answered with a response frame', () async {
      final accepted = await answerWhileWaiting(
        'srq-1',
        'approval',
        approvalParams,
        () => transport.answerApproval('srq-1', 'once'),
      );

      expect(accepted, isTrue);
      expect(gateway.responses, [
        {
          'jsonrpc': '2.0',
          'id': 'srq-1',
          'result': {'choice': 'once'},
        },
      ]);
      expect(gateway.methods, isNot(contains('approval.respond')));
    });

    test('a single clarify question becomes a one-question request', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-2', 'clarify', sid, {
          'question': 'Which colour?',
          'choices': ['red', 'blue'],
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ClarifyRequested>().single.request;
      expect(request.requestId, 'srq-2');
      expect(request.batch, isFalse);
      expect(request.questions.single.question, 'Which colour?');
      expect(request.questions.single.choices, ['red', 'blue']);
    });

    test(
      'a single clarify question is answered with a response frame',
      () async {
        final accepted = await answerWhileWaiting('srq-2', 'clarify', {
          'question': 'Which colour?',
        }, () => transport.answerClarify('srq-2', ['blue']));

        expect(accepted, isTrue);
        expect(gateway.responses.single['id'], 'srq-2');
        expect(gateway.responses.single['result'], {'answer': 'blue'});
        expect(gateway.methods, isNot(contains('clarify.respond')));
      },
    );

    test('a multi-select answer is a JSON array in a string', () async {
      await answerWhileWaiting(
        'srq-2',
        'clarify',
        {'question': 'Toppings?', 'multi_select': true},
        () => transport.answerClarify('srq-2', [
          'ham',
          'olives',
        ], multiSelect: true),
      );

      expect(gateway.responses.single['result'], {
        'answer': '["ham","olives"]',
      });
    });

    test('skipping a single question answers with an empty string', () async {
      await answerWhileWaiting('srq-2', 'clarify', {
        'question': 'Which colour?',
      }, () => transport.answerClarify('srq-2', const []));

      expect(gateway.responses.single['result'], {'answer': ''});
    });

    const batchParams = {
      'questions': [
        {'qid': 'a', 'question': 'Name?', 'choices': null},
        {
          'qid': 'b',
          'question': 'Toppings?',
          'choices': ['ham'],
        },
      ],
    };

    test('a batch question is locked, not answered with a frame', () async {
      final accepted = await answerWhileWaiting(
        'srq-3',
        'clarify',
        batchParams,
        () => transport.answerClarify('srq-3', ['ham'], questionId: 'b'),
      );

      expect(accepted, isTrue);
      expect(gateway.requestOf('clarify.lock')['params'], {
        'request_id': 'srq-3',
        'question_id': 'b',
        'answer': 'ham',
      });
      expect(gateway.responses, isEmpty);
    });

    test('skipping a batch cancels it with an empty response frame', () async {
      final accepted = await answerWhileWaiting(
        'srq-3',
        'clarify',
        batchParams,
        () => transport.answerClarify('srq-3', const []),
      );

      expect(accepted, isTrue);
      expect(gateway.responses.single['id'], 'srq-3');
      expect(gateway.responses.single['result'], <String, Object?>{});
      expect(gateway.methods, isNot(contains('clarify.lock')));
    });

    test(
      'answering a clarify question twice never uses the event form',
      () async {
        await answerWhileWaiting(
          'srq-2',
          'clarify',
          {'question': 'Which colour?'},
          () async {
            await transport.answerClarify('srq-2', ['blue']);
            await transport.answerClarify('srq-2', ['blue']);
          },
        );

        expect(gateway.methods, isNot(contains('clarify.respond')));
      },
    );

    test('a batch lock on an ended request reports not accepted', () async {
      gateway.lockStatus = 'expired';

      final accepted = await answerWhileWaiting(
        'srq-3',
        'clarify',
        batchParams,
        () => transport.answerClarify('srq-3', ['ham'], questionId: 'b'),
      );

      expect(accepted, isFalse);
    });

    test('secret and sudo requests are shown and never answered', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-4', 'sudo', sid, {'command': 'apt install x'});
        g.serverRequest('srq-5', 'secret', sid, {
          'env_var': 'SERVICE_API_KEY',
          'prompt': 'Enter the key',
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final requests = events
          .whereType<UnsupportedRequested>()
          .map((e) => e.request)
          .toList();
      expect(requests.map((r) => r.requestId), ['srq-4', 'srq-5']);
      expect(requests.map((r) => r.kind), [
        UnsupportedKind.sudo,
        UnsupportedKind.secret,
      ]);
      await pumpEventQueue();
      expect(gateway.responses, isEmpty);
    });

    test('a request the app has no handler for is refused at once', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-6', 'vault.code', sid, {'site': 'example.com'});
        g.serverRequest('srq-7', 'terminal.read', sid);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();
      await pumpEventQueue();

      expect(events.map((e) => e.runtimeType), [ThreadBound, ReplyCompleted]);
      expect(gateway.responses, [
        {
          'jsonrpc': '2.0',
          'id': 'srq-6',
          'error': {'code': -32601, 'message': 'Method not found'},
        },
        {
          'jsonrpc': '2.0',
          'id': 'srq-7',
          'error': {'code': -32601, 'message': 'Method not found'},
        },
      ]);
    });

    test('an unhandled request of a session nobody here replies in is left '
        'alone', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-9', 'terminal.read', 'someone-else');
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      await reply();
      await pumpEventQueue();

      expect(gateway.responses, isEmpty);
    });

    test('an unhandled request after the reply ended is left alone', () async {
      gateway.turn = plainReply;
      await reply();

      gateway.serverRequest('srq-9', 'terminal.read', 'rt-1');
      await pumpEventQueue();

      expect(gateway.responses, isEmpty);
    });

    test('a request of another session is left alone', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-8', 'approval', 'someone-else', approvalParams);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();
      await pumpEventQueue();

      expect(events.whereType<ApprovalRequested>(), isEmpty);
      expect(gateway.responses, isEmpty);
    });

    test('a withdrawn request expires its card', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-1', 'approval', sid, approvalParams);
        g.event('request.cancel', sid, {
          'id': 'srq-1',
          'method': 'approval',
          'reason': 'timeout',
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.whereType<InputRequestExpired>().single.requestId, 'srq-1');
    });

    test('an answer after the turn ended sends nothing', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-1', 'approval', sid, approvalParams);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };
      await reply();

      expect(await transport.answerApproval('srq-1', 'once'), isFalse);
      expect(gateway.responses, isEmpty);
    });

    test('the event form still works beside it', () async {
      gateway.turn = (g, sid) {
        g.event('approval.request', sid, {
          ...approvalParams,
          'request_id': 'r1',
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(
        events.whereType<ApprovalRequested>().single.request.requestId,
        'r1',
      );
    });
  });

  group('skipping a request the app cannot answer', () {
    test('a sudo server request is skipped with an empty value', () async {
      final accepted = await answerWhileRaising(
        (g, sid) => g.serverRequest('srq-4', 'sudo', sid, {'command': 'x'}),
        () => transport.skipUnsupported('srq-4', UnsupportedKind.sudo),
      );

      expect(accepted, isTrue);
      expect(gateway.responses, [
        {
          'jsonrpc': '2.0',
          'id': 'srq-4',
          'result': {'value': ''},
        },
      ]);
      expect(gateway.methods, isNot(contains('sudo.respond')));
    });

    test('a secret server request is skipped with an empty value', () async {
      await answerWhileRaising(
        (g, sid) => g.serverRequest('srq-5', 'secret', sid, {
          'env_var': 'SERVICE_API_KEY',
          'prompt': 'Enter the key',
        }),
        () => transport.skipUnsupported('srq-5', UnsupportedKind.secret),
      );

      expect(gateway.responses.single['id'], 'srq-5');
      expect(gateway.responses.single['result'], {'value': ''});
    });

    test('a sudo event is skipped with an empty password', () async {
      final accepted = await answerWhileRaising(
        (g, sid) => g.event('sudo.request', sid, {'request_id': 'r6'}),
        () => transport.skipUnsupported('r6', UnsupportedKind.sudo),
      );

      expect(accepted, isTrue);
      expect(gateway.requestOf('sudo.respond')['params'], {
        'request_id': 'r6',
        'password': '',
      });
      expect(gateway.responses, isEmpty);
    });

    test('a secret event is skipped with an empty value', () async {
      await answerWhileRaising(
        (g, sid) => g.event('secret.request', sid, {'request_id': 'r5'}),
        () => transport.skipUnsupported('r5', UnsupportedKind.secret),
      );

      expect(gateway.requestOf('secret.respond')['params'], {
        'request_id': 'r5',
        'value': '',
      });
    });

    test(
      'an event skip the gateway reports as expired is not accepted',
      () async {
        gateway.skipStatus = 'expired';

        final accepted = await answerWhileRaising(
          (g, sid) => g.event('sudo.request', sid, {'request_id': 'r6'}),
          () => transport.skipUnsupported('r6', UnsupportedKind.sudo),
        );

        expect(accepted, isFalse);
      },
    );

    test('a request nothing is waiting on sends nothing', () async {
      expect(
        await transport.skipUnsupported('nope', UnsupportedKind.sudo),
        isFalse,
      );
      expect(gateway.requests, isEmpty);
      expect(gateway.responses, isEmpty);
    });

    test('a skip after the turn ended sends nothing', () async {
      gateway.turn = (g, sid) {
        g.serverRequest('srq-4', 'sudo', sid);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };
      await reply();

      expect(
        await transport.skipUnsupported('srq-4', UnsupportedKind.sudo),
        isFalse,
      );
      expect(gateway.responses, isEmpty);
      expect(gateway.methods, isNot(contains('sudo.respond')));
    });
  });

  group('attachments', () {
    final photo = OutgoingAttachment(
      name: 'photo.png',
      kind: AttachmentKind.image,
      mimeType: 'image/png',
      read: () async => Uint8List.fromList([1, 2, 3]),
    );
    final report = OutgoingAttachment(
      name: 'report.pdf',
      kind: AttachmentKind.file,
      mimeType: 'application/pdf',
      read: () async => Uint8List.fromList([4, 5, 6, 7]),
    );

    Future<Object?> failure(List<OutgoingAttachment> attachments) async {
      try {
        await reply(attachments: attachments);
      } on Object catch (error) {
        return error;
      }
      return null;
    }

    test('an image is attached to the session before the prompt', () async {
      gateway.turn = plainReply;

      await reply(text: 'what is this?', attachments: [photo]);

      expect(gateway.methods, [
        'client.capabilities',
        'session.create',
        'image.attach_bytes',
        'prompt.submit',
      ]);
      expect(gateway.requestOf('image.attach_bytes')['params'], {
        'session_id': 'rt-1',
        'content_base64': base64Encode([1, 2, 3]),
        'filename': 'photo.png',
      });
      expect(gateway.requestOf('prompt.submit')['params'], {
        'session_id': 'rt-1',
        'text': 'what is this?',
      });
    });

    test('an image sent without text submits no text', () async {
      gateway.turn = plainReply;

      await reply(text: '', attachments: [photo]);

      expect(gateway.requestOf('prompt.submit')['params'], {
        'session_id': 'rt-1',
        'text': '',
      });
    });

    test('a file is attached as a data URL and its reference sent', () async {
      gateway.turn = plainReply;

      await reply(text: '', attachments: [report]);

      expect(gateway.methods, [
        'client.capabilities',
        'session.create',
        'file.attach',
        'prompt.submit',
      ]);
      expect(gateway.requestOf('file.attach')['params'], {
        'session_id': 'rt-1',
        'name': 'report.pdf',
        'data_url': 'data:application/pdf;base64,${base64Encode([4, 5, 6, 7])}',
      });
      expect(gateway.requestOf('prompt.submit')['params'], {
        'session_id': 'rt-1',
        'text': '@file:attachments/report.pdf',
      });
    });

    test('a file with no known type goes up as a binary stream', () async {
      gateway.turn = plainReply;
      final unknown = OutgoingAttachment(
        name: 'blob',
        kind: AttachmentKind.file,
        read: () async => Uint8List.fromList([9]),
      );

      await reply(attachments: [unknown]);

      expect(
        (gateway.requestOf('file.attach')['params'] as Map)['data_url'],
        startsWith('data:application/octet-stream;base64,'),
      );
    });

    test('the references of files follow the typed text', () async {
      gateway.turn = plainReply;

      await reply(text: 'summarise', attachments: [photo, report]);

      expect(gateway.requestOf('prompt.submit')['params'], {
        'session_id': 'rt-1',
        'text': 'summarise\n@file:attachments/report.pdf',
      });
    });

    test('attachments go to the resumed session', () async {
      gateway.turn = plainReply;

      await reply(threadId: 'stored-2', attachments: [photo]);

      expect(
        (gateway.requestOf('image.attach_bytes')['params']
            as Map)['session_id'],
        'rt-2',
      );
    });

    test(
      'an image the server does not take as one goes up as a file',
      () async {
        gateway.turn = plainReply;
        gateway.attachFailures['image.attach_bytes photo.heic'] = (
          4016,
          'unsupported image',
        );
        final heic = OutgoingAttachment(
          name: 'photo.heic',
          kind: AttachmentKind.image,
          mimeType: 'image/heic',
          read: () async => Uint8List.fromList([1]),
        );

        await reply(text: 'see', attachments: [heic]);

        expect(gateway.methods, [
          'client.capabilities',
          'session.create',
          'image.attach_bytes',
          'file.attach',
          'prompt.submit',
        ]);
        expect(gateway.requestOf('prompt.submit')['params'], {
          'session_id': 'rt-1',
          'text': 'see\n@file:attachments/photo.heic',
        });
      },
    );

    test('the thread is bound before an attachment fails', () async {
      gateway.attachFailures['file.attach report.pdf'] = (5028, 'disk full');

      await expectLater(
        transport.send(text: 'x', attachments: [report]),
        emitsInOrder([isA<ThreadBound>(), emitsError(anything)]),
      );
    });

    test('a rejected attachment ends the send and submits nothing', () async {
      gateway.attachFailures['file.attach report.pdf'] = (5028, 'disk full');

      final error = await failure([report]);

      expect(error, isA<AttachmentException>());
      expect(
        (error! as AttachmentException).message,
        'Could not attach report.pdf: disk full',
      );
      expect(gateway.methods, isNot(contains('prompt.submit')));
    });

    test('images queued before a failure are detached again', () async {
      gateway.attachFailures['file.attach report.pdf'] = (5028, 'disk full');

      await failure([photo, report]);

      expect(gateway.methods, contains('image.detach'));
      expect(gateway.requestOf('image.detach')['params'], {
        'session_id': 'rt-1',
        'path': '/home/u/.hermes/images/upload_1.png',
      });
      expect(gateway.queuedImages, isEmpty);
    });

    test('a failure with nothing queued detaches nothing', () async {
      gateway.attachFailures['file.attach report.pdf'] = (5028, 'disk full');

      await failure([report]);

      expect(gateway.methods, isNot(contains('image.detach')));
    });

    test('a rejected prompt detaches the images it would have taken', () async {
      gateway.rejectSubmit = true;

      final error = await failure([photo]);

      expect(error, isA<GatewayRpcException>());
      expect(gateway.queuedImages, isEmpty);
    });

    test('a server without the attach methods says so', () async {
      gateway.unknownMethods.add('image.attach_bytes');

      final error = await failure([photo]);

      expect(error, isA<AttachmentException>());
      expect(
        (error! as AttachmentException).message,
        "This Hermes server can't receive attachments. "
        'Update Hermes to attach files.',
      );
      expect(gateway.methods, isNot(contains('prompt.submit')));
    });

    test('a server without file.attach says so', () async {
      gateway.unknownMethods.add('file.attach');

      final error = await failure([report]);

      expect(error, isA<AttachmentException>());
      expect(
        (error! as AttachmentException).message,
        contains('Update Hermes'),
      );
    });

    test('a file over the limit is refused without going up', () async {
      final huge = OutgoingAttachment(
        name: 'huge.bin',
        kind: AttachmentKind.file,
        read: () async => Uint8List(kMaxAttachmentBytes + 1),
      );

      final error = await failure([huge]);

      expect(
        (error! as AttachmentException).message,
        "huge.bin is larger than 25 MB and can't be sent.",
      );
      expect(gateway.methods, isNot(contains('file.attach')));
      expect(gateway.methods, isNot(contains('prompt.submit')));
    });

    test('a file that cannot be read is named', () async {
      final broken = OutgoingAttachment(
        name: 'gone.txt',
        kind: AttachmentKind.file,
        read: () async => throw const FileSystemException('gone'),
      );

      final error = await failure([broken]);

      expect(
        (error! as AttachmentException).message,
        'Could not attach gone.txt: the file could not be read.',
      );
    });

    test(
      'a dropped socket during an upload is not blamed on the file',
      () async {
        final slow = OutgoingAttachment(
          name: 'slow.pdf',
          kind: AttachmentKind.file,
          read: () async {
            gateway.drop();
            return Uint8List.fromList([1]);
          },
        );

        expect(await failure([slow]), isA<GatewayConnectionClosed>());
      },
    );

    test('a send without attachments makes no attach call', () async {
      gateway.turn = plainReply;

      await reply();

      expect(gateway.methods, [
        'client.capabilities',
        'session.create',
        'prompt.submit',
      ]);
    });
  });

  group('stopping a reply', () {
    /// Starts a turn that never completes on its own, calls [stop] while it
    /// runs, then completes it.
    Future<T> stopWhileReplying<T>(
      Future<T> Function() stop, {
      String? threadId,
    }) async {
      gateway.turn = (g, sid) => g.event('message.start', sid);
      final done = Completer<void>();
      late T result;
      transport.send(threadId: threadId, text: 'hi').listen((e) async {
        if (e is ReplyStarted) {
          result = await stop();
          gateway.event('message.complete', gateway.lastSessionId, {
            'text': '',
            'status': 'interrupted',
          });
        }
      }, onDone: done.complete);
      await done.future;
      return result;
    }

    test('interrupts the runtime session of a thread it created', () async {
      final stopped = await stopWhileReplying(
        () => transport.stopReply('stored-1'),
      );

      expect(stopped, isTrue);
      expect(gateway.requestOf('session.interrupt')['params'], {
        'session_id': 'rt-1',
      });
    });

    test('interrupts the runtime session of a thread it resumed', () async {
      await stopWhileReplying(
        () => transport.stopReply('stored-2'),
        threadId: 'stored-2',
      );

      expect(gateway.requestOf('session.interrupt')['params'], {
        'session_id': 'rt-2',
      });
    });

    test('nothing running reports not stopped', () async {
      gateway.interruptStatus = 'not_interrupted';

      final stopped = await stopWhileReplying(
        () => transport.stopReply('stored-1'),
      );

      expect(stopped, isFalse);
    });

    test('a thread with no reply in flight sends nothing', () async {
      expect(await transport.stopReply('stored-1'), isFalse);
      expect(gateway.requests, isEmpty);
    });

    test('a reply that ended can no longer be stopped', () async {
      gateway.turn = plainReply;
      await reply();

      expect(await transport.stopReply('stored-1'), isFalse);
      expect(gateway.methods, isNot(contains('session.interrupt')));
    });

    test('an interrupted turn completes as stopped, not failed', () async {
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': '',
        'status': 'interrupted',
      });

      final completed = (await reply()).last as ReplyCompleted;

      expect(completed.stopped, isTrue);
      expect(completed.failed, isFalse);
    });
  });

  group('follow-up turns', () {
    test('a turn Hermes chains after the reply is followed', () async {
      gateway.turn = plainReply;
      await reply();

      final followed = transport.followUps('stored-1').toList();
      gateway.event('message.start', 'rt-1');
      gateway.event('message.delta', 'rt-1', {'text': 'Checking'});
      gateway.event('message.complete', 'rt-1', {
        'text': 'Checked',
        'status': 'complete',
      });
      await pumpEventQueue();
      gateway.drop();

      final events = await followed;
      expect(events.map((e) => e.runtimeType), [
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
      expect((events.last as ReplyCompleted).text, 'Checked');
    });

    test('a turn that started before the listener came is not lost', () async {
      gateway.turn = (g, sid) {
        plainReply(g, sid);
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'More'});
      };
      await reply();

      final followed = transport.followUps('stored-1').toList();
      await pumpEventQueue();
      gateway.event('message.complete', 'rt-1', {
        'text': 'More',
        'status': 'complete',
      });
      await pumpEventQueue();
      gateway.drop();

      expect((await followed).map((e) => e.runtimeType), [
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
    });

    test('a title that arrives after the reply is forwarded', () async {
      gateway.turn = plainReply;
      await reply();

      final followed = transport.followUps('stored-1').toList();
      gateway.event('session.title', 'rt-1', {'title': 'Late'});
      await pumpEventQueue();
      gateway.drop();

      expect((await followed).single, isA<ThreadTitled>());
    });

    test('a follow-up turn can be stopped and its approval answered', () async {
      gateway.turn = plainReply;
      await reply();

      final events = <ChatEvent>[];
      final subscription = transport.followUps('stored-1').listen(events.add);
      gateway.event('message.start', 'rt-1');
      gateway.event('approval.request', 'rt-1', {
        'request_id': 'ap-1',
        'command': 'ls',
      });
      await pumpEventQueue();

      expect(await transport.stopReply('stored-1'), isTrue);
      expect(await transport.answerApproval('ap-1', 'once'), isTrue);
      await subscription.cancel();
    });

    test('a connection lost mid-turn is an error', () async {
      gateway.turn = plainReply;
      await reply();

      final followed = transport.followUps('stored-1').toList();
      gateway.event('message.start', 'rt-1');
      await pumpEventQueue();
      gateway.drop();

      await expectLater(followed, throwsA(isA<GatewayConnectionClosed>()));
    });

    test('a connection lost between turns just ends the stream', () async {
      gateway.turn = plainReply;
      await reply();

      final followed = transport.followUps('stored-1').toList();
      gateway.drop();

      expect(await followed, isEmpty);
    });

    test('there is nothing to follow for a thread with no reply', () async {
      expect(await transport.followUps('stored-1').toList(), isEmpty);
    });

    test('the next send takes over from the follow-up listener', () async {
      gateway.turn = plainReply;
      await reply();
      final followed = transport.followUps('stored-1').toList();

      final events = await reply(threadId: 'stored-1');
      await pumpEventQueue();

      expect(events.last, isA<ReplyCompleted>());
      expect(await followed, isEmpty);
    });
  });

  group('after the app slept', () {
    late List<FakeGateway> gateways;
    late HermesGatewayTransport sleeper;
    late void Function(FakeGateway, String) turn;

    setUp(() {
      gateways = [];
      turn = _reply;
      sleeper = HermesGatewayTransport(
        connect: () async {
          final next = FakeGateway()..turn = turn;
          gateways.add(next);
          return next.channel;
        },
        requestTimeout: const Duration(milliseconds: 50),
        probeTimeout: const Duration(milliseconds: 50),
      );
    });

    tearDown(() => sleeper.close());

    Future<List<ChatEvent>> send() => sleeper.send(text: 'hi').toList();

    test('a connection that still answers is kept', () async {
      await send();

      await sleeper.checkConnection();
      await send();

      expect(gateways, hasLength(1));
    });

    test(
      'a connection that no longer answers is dropped and reopened',
      () async {
        await send();
        gateways.single.deaf = true;

        await sleeper.checkConnection();
        await gateways.single.closedByClient;
        await send();

        expect(gateways, hasLength(2));
      },
    );

    test('checking with no connection open opens none', () async {
      await sleeper.checkConnection();

      expect(gateways, isEmpty);
    });

    test('a gateway that predates the probe still counts as alive', () async {
      await send();
      gateways.single.capabilitiesUnknown = true;

      await sleeper.checkConnection();
      await send();

      expect(gateways, hasLength(1));
    });

    test(
      'a reply in flight ends when the dead connection is dropped',
      () async {
        turn = (_, _) {};
        final outcome = sleeper.send(text: 'hi').toList();
        await pumpEventQueue();
        gateways.single.deaf = true;

        await sleeper.checkConnection();

        await expectLater(outcome, throwsA(isA<GatewayConnectionClosed>()));
      },
    );

    test(
      'a send the gateway never answers fails and the next reconnects',
      () async {
        await send();
        gateways.single.silent.add('prompt.submit');

        await expectLater(send(), throwsA(isA<GatewayConnectionClosed>()));
        await send();

        expect(gateways, hasLength(2));
      },
    );

    test(
      'a session the gateway never answers fails instead of hanging',
      () async {
        await send();
        gateways.single.silent.add('session.create');

        await expectLater(send(), throwsA(isA<GatewayConnectionClosed>()));
      },
    );
  });

  group('reattaching to a running turn', () {
    late List<FakeGateway> gateways;
    late HermesGatewayTransport reattaching;

    /// The first connection drops right after submitting, as a socket the OS
    /// killed while the app slept does; later ones answer `session.resume`
    /// as a server that is still running the turn does.
    setUp(() {
      gateways = [];
      reattaching = HermesGatewayTransport(
        connect: () async {
          final next = FakeGateway();
          if (gateways.isEmpty) {
            next.turn = (g, sid) {
              g.event('message.start', sid);
              g.event('message.delta', sid, {'text': 'Thinking'});
              g.drop();
            };
          } else {
            next.resumeResult = {'session_id': 'rt-1', 'running': true};
          }
          gateways.add(next);
          return next.channel;
        },
        requestTimeout: const Duration(milliseconds: 50),
      );
    });

    tearDown(() => reattaching.close());

    test(
      'a reply picks back up once the resumed session says it is still running',
      () async {
        final result = reattaching.send(text: 'hi').toList();
        await pumpEventQueue();

        expect(gateways, hasLength(2));
        gateways[1].event('message.delta', 'rt-1', {'text': ' more'});
        gateways[1].event('message.complete', 'rt-1', {
          'text': 'Thinking more',
          'status': 'complete',
        });

        expect((await result).map((e) => e.runtimeType), [
          ThreadBound,
          ReplyStarted,
          ReplyDelta,
          ReplyDelta,
          ReplyCompleted,
        ]);
      },
    );

    test('a follow-up turn picks back up the same way', () async {
      gateways.add(FakeGateway()..turn = plainReply);
      reattaching = HermesGatewayTransport(
        connect: () async => gateways.length == 1
            ? gateways.single.channel
            : gateways.last.channel,
        requestTimeout: const Duration(milliseconds: 50),
      );
      await reattaching.send(text: 'hi').toList();
      final follow = reattaching.followUps('stored-1').toList();
      gateways.single.event('message.start', 'rt-1');
      gateways.single.event('message.delta', 'rt-1', {'text': 'Checking'});
      gateways.add(
        FakeGateway()..resumeResult = {'session_id': 'rt-1', 'running': true},
      );
      gateways[0].drop();
      await pumpEventQueue();

      expect(gateways, hasLength(2));
      gateways.last.event('message.complete', 'rt-1', {
        'text': 'Checking done',
        'status': 'complete',
      });
      await pumpEventQueue();
      gateways.last.drop();

      expect((await follow).map((e) => e.runtimeType), [
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
    });

    test(
      'gives up when the resumed session says the turn already ended',
      () async {
        // The default setUp already answers a resume with `running: true`;
        // override the second connection to say the turn ended instead.
        reattaching = HermesGatewayTransport(
          connect: () async {
            final next = FakeGateway();
            if (gateways.isEmpty) {
              next.turn = (g, sid) => g.drop();
            } else {
              next.resumeResult = {'running': false};
            }
            gateways.add(next);
            return next.channel;
          },
          requestTimeout: const Duration(milliseconds: 50),
        );

        await expectLater(
          reattaching.send(text: 'hi').toList(),
          throwsA(isA<GatewayConnectionClosed>()),
        );
      },
    );

    test(
      'a turn that finished while disconnected completes with the stored reply',
      () async {
        reattaching = HermesGatewayTransport(
          connect: () async {
            final next = FakeGateway();
            if (gateways.isEmpty) {
              next.turn = (g, sid) {
                g.event('message.start', sid);
                g.event('message.delta', sid, {'text': 'Shall I'});
                g.drop();
              };
            } else {
              next.resumeResult = {
                'session_id': 'rt-1',
                'running': false,
                'messages': [
                  {'role': 'user', 'text': 'hi'},
                  {'role': 'tool', 'name': 'cronjob_manage'},
                  {'role': 'assistant', 'text': 'Shall I run it now?'},
                ],
              };
            }
            gateways.add(next);
            return next.channel;
          },
          requestTimeout: const Duration(milliseconds: 50),
        );

        final events = await reattaching.send(text: 'hi').toList();

        expect(
          events.whereType<ReplyCompleted>().single,
          isA<ReplyCompleted>()
              .having((e) => e.text, 'text', 'Shall I run it now?')
              .having((e) => e.failed, 'failed', isFalse),
        );
      },
    );

    test(
      'a follow-up turn that finished while disconnected completes too',
      () async {
        gateways.add(FakeGateway()..turn = plainReply);
        reattaching = HermesGatewayTransport(
          connect: () async => gateways.length == 1
              ? gateways.single.channel
              : gateways.last.channel,
          requestTimeout: const Duration(milliseconds: 50),
        );
        await reattaching.send(text: 'hi').toList();
        final follow = reattaching.followUps('stored-1').toList();
        gateways.single.event('message.start', 'rt-1');
        gateways.single.event('message.delta', 'rt-1', {'text': 'Checking'});
        gateways.add(
          FakeGateway()
            ..resumeResult = {
              'session_id': 'rt-1',
              'running': false,
              'messages': [
                {'role': 'assistant', 'text': 'Checking done'},
              ],
            },
        );
        gateways[0].drop();

        expect(
          (await follow).last,
          isA<ReplyCompleted>().having((e) => e.text, 'text', 'Checking done'),
        );
      },
    );

    test('the runtime session after a reattach can still be stopped', () async {
      final result = reattaching.send(text: 'hi').toList();
      await pumpEventQueue();
      gateways[1].interruptStatus = 'interrupted';

      expect(await reattaching.stopReply('stored-1'), isTrue);
      expect(gateways[1].methods, contains('session.interrupt'));

      gateways[1].event('message.complete', 'rt-1', {
        'text': 'Thinking',
        'status': 'interrupted',
      });
      await result;
    });
  });
}

void _reply(FakeGateway g, String sid) {
  g.event('message.start', sid);
  g.event('message.complete', sid, {'text': 'Hello', 'status': 'complete'});
}
