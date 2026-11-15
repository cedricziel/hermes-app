import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart' show ProfileCreate, RawConfigUpdate;
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

/// What the pinned Hermes does with a chat turn when its gateway socket goes
/// away: the turn's survival, what a reconnect can replay, and what a restarted
/// backend still knows. The answers were recorded against a real dashboard and
/// are summarised in `docs/architecture/gateway.md`.
///
///     scripts/verify.sh contract
///
/// or, by hand, against a throwaway backend:
///
///     HERMES_DEV_URL=$(scripts/dev-backend.sh url) flutter test \
///       test/gateway_reconnect_contract_test.dart
///
/// Skipped when `HERMES_DEV_URL` is unset. The turns run on a scripted model
/// this test serves on the loopback interface (a `terminal` call that sleeps),
/// in a throwaway profile named `contract-reconnect-…` that is deleted after:
/// no provider, no key, no cost. Like the other throwaway-profile tests, a
/// second run against the same backend fails until it restarts.
///
/// The restart group also needs `HERMES_DEV_RESTART_SCRIPT`, a script that
/// takes `term` or `kill`, stops the backend that way and starts it again on
/// the same port with the same `HERMES_HOME` (`scripts/verify.sh` writes one
/// for a backend of its own). Without it the group is skipped.
void main() {
  final url = Platform.environment['HERMES_DEV_URL'];
  final restartScript = Platform.environment['HERMES_DEV_RESTART_SCRIPT'];
  final skip = url == null ? 'set HERMES_DEV_URL to run' : null;
  final restartSkip =
      skip ??
      (restartScript == null
          ? 'set HERMES_DEV_RESTART_SCRIPT to restart the backend'
          : null);

  late HermesApiClient client;
  late HttpServer model;
  final profile = 'contract-reconnect-${DateTime.now().millisecondsSinceEpoch}';

  Future<HermesApiClient> freshClient() async {
    final page = await Dio().get<String>('$url/');
    final token = RegExp(r'__HERMES_SESSION_TOKEN__="([^"]+)"')
        .firstMatch(page.data ?? '')
        ?.group(1);
    return HermesApiClient(
      Dio(
        BaseOptions(baseUrl: url!, headers: {'X-Hermes-Session-Token': ?token}),
      ),
    );
  }

  setUpAll(() async {
    if (url == null) return;
    client = await freshClient();
    model = await _serveSleepingModel();
    await client.raw.createProfileEndpointApiProfilesPost(
      profileCreate: ProfileCreate(name: profile, noSkills: true),
    );
    await client.raw.updateConfigRawApiConfigRawPut(
      profile: profile,
      rawConfigUpdate: RawConfigUpdate(
        yamlText:
            '''
model:
  default: "scripted"
  provider: "custom"
  base_url: "http://127.0.0.1:${model.port}/v1"
  api_key: "scripted"
  context_length: 131072
''',
      ),
    );
  });

  tearDownAll(() async {
    if (url == null) return;
    try {
      // A restart changes the session token, so read the page again.
      client = await freshClient();
      await client.raw.deleteProfileEndpointApiProfilesNameDelete(
        name: profile,
      );
    } finally {
      await model.close(force: true);
    }
  });

  Future<_Tap> connect() async {
    final tap = _Tap(
      GatewayRpcClient(
        await hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        )(),
      ),
    );
    addTearDown(tap.close);
    // `gateway.ready` is the first frame; the client keeps its epoch.
    await tap.until(() => tap.rpc.epoch != null, 'gateway.ready');
    return tap;
  }

  /// A new chat with a turn running [sleepSeconds] in a `terminal` call, once
  /// the call has started.
  Future<_Turn> startTurn(_Tap tap, int sleepSeconds) async {
    final created = await tap.rpc.request('session.create', {
      'profile': profile,
      'source': 'hermes_app',
    });
    final sid = created['session_id'] as String;
    final submit = await tap.rpc.request('prompt.submit', {
      'session_id': sid,
      'text': 'Hold [[sleep=$sleepSeconds]]',
    });
    expect(submit['status'], 'streaming');
    await tap.until(
      () => tap.types(sid).contains('tool.start'),
      'the terminal call to start',
    );
    // `session.usage` follows `tool.start` a moment later; after it the turn
    // is quiet until the tool ends.
    await tap.until(
      () => tap.types(sid).contains('session.usage'),
      'the usage report that follows the call',
    );
    return _Turn(
      sid: sid,
      stored: created['stored_session_id'] as String,
      lastSeq: tap.lastSeq(sid),
    );
  }

  Future<Map<String, Object?>> resume(_Tap tap, String id) => tap.rpc.request(
    'session.resume',
    {'session_id': id, 'profile': profile, 'source': 'hermes_app'},
  );

  Future<Map<String, Object?>> since(_Tap tap, _Turn turn) => tap.rpc.request(
    'session.events.since',
    {'session_id': turn.sid, 'last_seen': turn.lastSeq},
  );

  Future<GatewayRpcException> refused(Future<Object?> call) async {
    try {
      await call;
    } on GatewayRpcException catch (error) {
      return error;
    }
    fail('the gateway answered; it was expected to refuse');
  }

  group('a gateway socket that drops mid-turn', () {
    test(
      'the turn keeps running, a reconnect resumes the same runtime and '
      'undo is refused as busy',
      () async {
        final owner = await connect();
        final epoch = owner.rpc.epoch;
        final turn = await startTurn(owner, 20);
        await owner.close();
        await Future<void>.delayed(const Duration(seconds: 3));

        final back = await connect();
        // Same process, same numbering: the watermark is still good.
        expect(back.rpc.epoch, epoch);

        final listed = await back.rpc.request('session.active_list', {});
        final rows = (listed['sessions'] as List).cast<Map<String, Object?>>();
        final row = rows.singleWhere((r) => r['id'] == turn.sid);
        expect(row['status'], 'working');
        expect(row['session_key'], turn.stored);

        // Nothing happened while the tool ran, so there is nothing to replay.
        final replay = await since(back, turn);
        expect(replay['events'], isEmpty);
        expect(replay['count'], 0);
        expect(replay['latest_seq'], turn.lastSeq);
        expect(replay['truncated'], false);
        expect(replay['epoch'], epoch);
        expect(replay['open_requests'], isEmpty);

        // Resume by the stored id: the same live runtime, still running, with
        // the reply so far as `inflight`.
        final resumed = await resume(back, turn.stored);
        expect(resumed['session_id'], turn.sid);
        expect(resumed['running'], true);
        expect(resumed['status'], 'working');
        final inflight = resumed['inflight'] as Map<String, Object?>;
        expect(inflight['streaming'], true);
        expect(inflight['user'], 'Hold [[sleep=20]]');

        // Undo refuses while the turn runs.
        final busy = await refused(
          back.rpc.request('session.undo', {'session_id': turn.sid}),
        );
        expect(busy.code, 4009);

        // The resumed socket receives the rest of the turn live; stop it
        // rather than wait out the sleep.
        final stopped = await back.rpc.request('session.interrupt', {
          'session_id': turn.sid,
        });
        expect(stopped['status'], 'interrupted');
        await back.until(
          () => back.types(turn.sid).contains('message.complete'),
          'the interrupted turn to complete',
          within: const Duration(seconds: 30),
        );
        // Seqs continue from where the first socket stopped.
        final seqs = back.seqs(turn.sid);
        expect(seqs.first, turn.lastSeq + 1);
        for (var i = 1; i < seqs.length; i++) {
          expect(seqs[i], seqs[i - 1] + 1, reason: 'seqs have no hole');
        }
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'a turn that ends while the socket is away is replayed in order and '
      'shows as idle, with its reply stored, on the same runtime',
      () async {
        final owner = await connect();
        final turn = await startTurn(owner, 3);
        await owner.close();
        // Longer than the sleep, inside the 20 s grace Hermes keeps a
        // dropped session for.
        await Future<void>.delayed(const Duration(seconds: 7));

        final back = await connect();
        final replay = await since(back, turn);
        final events = (replay['events'] as List).cast<Map<String, Object?>>();
        final types = [for (final e in events) e['type']];
        expect(types.first, 'tool.complete');
        expect(types, contains('message.complete'));
        // The order of the title and the completion varies; the idle report
        // is among them.
        expect(types, contains('session.info'));
        final seqs = [for (final e in events) e['seq'] as int];
        expect(seqs.first, turn.lastSeq + 1);
        for (var i = 1; i < seqs.length; i++) {
          expect(seqs[i], seqs[i - 1] + 1, reason: 'seqs have no hole');
        }
        expect(replay['latest_seq'], seqs.last);
        expect(replay['count'], events.length);
        expect(replay['truncated'], false);
        // The replayed events carry the session they belong to.
        expect(events.map((e) => e['session_id']).toSet(), {turn.sid});
        final complete = events.singleWhere(
          (e) => e['type'] == 'message.complete',
        );
        expect((complete['payload'] as Map)['text'], 'Scripted done.');

        final resumed = await resume(back, turn.stored);
        expect(resumed['session_id'], turn.sid);
        expect(resumed['running'], false);
        expect(resumed['status'], 'idle');
        expect(resumed['inflight'], isNull);
        final messages = (resumed['messages'] as List)
            .cast<Map<String, Object?>>();
        expect(messages.last['role'], 'assistant');
        expect(messages.last['text'], 'Scripted done.');
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'past the 20 s grace the finished turn is still replayable from the '
      'ring, its runtime id is gone and a resume mints a new one',
      () async {
        final owner = await connect();
        final turn = await startTurn(owner, 2);
        await owner.close();
        // Grace (20 s) plus the reaper's first look.
        await Future<void>.delayed(const Duration(seconds: 25));

        final back = await connect();
        // The ring outlives the runtime.
        final replay = await since(back, turn);
        expect(replay['truncated'], false);
        expect([
          for (final e in replay['events'] as List) (e as Map)['type'],
        ], contains('message.complete'));

        // The runtime is gone: a call that names it says so with 4001, and
        // the app is expected to resume by the stored id.
        expect(
          (await refused(
            back.rpc.request('session.undo', {'session_id': turn.sid}),
          )).code,
          4001,
        );
        final listed = await back.rpc.request('session.active_list', {});
        expect([
          for (final r in listed['sessions'] as List) (r as Map)['id'],
        ], isNot(contains(turn.sid)));

        final resumed = await resume(back, turn.stored);
        expect(resumed['session_id'], isNot(turn.sid));
        expect(resumed['session_key'], turn.stored);
        expect(resumed['running'], false);
        expect(resumed['inflight'], isNull);
        final messages = (resumed['messages'] as List)
            .cast<Map<String, Object?>>();
        expect(messages.last['text'], 'Scripted done.');
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('a restarted backend', () {
    Future<void> restart(String how) async {
      final result = await Process.run('bash', [restartScript!, how]);
      expect(
        result.exitCode,
        0,
        reason: 'restart script: ${result.stdout}${result.stderr}',
      );
      // A new process has a new session token.
      client = await freshClient();
    }

    test(
      'after a graceful stop the old runtime id is gone everywhere, the '
      'epoch changes and the stored id still opens the chat on a new runtime',
      () async {
        final owner = await connect();
        final epoch = owner.rpc.epoch;
        final turn = await startTurn(owner, 60);
        await restart('term');
        // The server told the socket it was restarting (WebSocket 1012).
        await owner.until(() => owner.rpc.isClosed, 'the old socket to close');

        final back = await connect();
        expect(back.rpc.epoch, isNot(epoch));

        final listed = await back.rpc.request('session.active_list', {});
        expect(listed['sessions'], isEmpty);

        // Its numbering restarted: nothing is truncated, nothing to replay.
        final replay = await since(back, turn);
        expect(replay['events'], isEmpty);
        expect(replay['latest_seq'], 0);
        expect(replay['truncated'], false);
        expect(replay['epoch'], back.rpc.epoch);

        // A runtime id the new process never minted.
        expect(
          (await refused(
            back.rpc.request('session.interrupt', {'session_id': turn.sid}),
          )).code,
          4001,
        );
        expect(
          (await refused(
            back.rpc.request('session.undo', {'session_id': turn.sid}),
          )).code,
          4001,
        );
        // Resume takes a stored id; the runtime id is not one.
        expect((await refused(resume(back, turn.sid))).code, 4007);

        // The stored id still opens the chat, on a new runtime, idle.
        final resumed = await resume(back, turn.stored);
        expect(resumed['session_id'], isNot(turn.sid));
        expect(resumed['running'], false);
        expect(resumed['status'], 'idle');
        final messages = (resumed['messages'] as List)
            .cast<Map<String, Object?>>();
        expect(messages.first['role'], 'user');
        expect(messages.first['text'], 'Hold [[sleep=60]]');
        // Whether Hermes reruns the turn after a SIGTERM is a race: it
        // interrupts the turn on its way out and only a turn that settles in
        // time clears its crash marker. Most stops leave it, so this answers
        // `auto_continue`; either way, stop what it started.
        final auto = resumed['auto_continue'];
        if (auto != null) {
          expect((auto as Map)['attempt'], 1);
          await back.rpc.request('session.interrupt', {
            'session_id': resumed['session_id'],
          });
        }
      },
      skip: restartSkip,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'after a kill the resume reports auto_continue and Hermes runs the '
      'interrupted turn again by itself',
      () async {
        final owner = await connect();
        final turn = await startTurn(owner, 60);
        await restart('kill');
        // The process died without a close frame.
        await owner.until(() => owner.rpc.isClosed, 'the old socket to close');

        final back = await connect();
        expect((await refused(resume(back, turn.sid))).code, 4007);
        expect(
          (await refused(
            back.rpc.request('session.interrupt', {'session_id': turn.sid}),
          )).code,
          4001,
        );

        final resumed = await resume(back, turn.stored);
        final next = resumed['session_id'] as String;
        expect(next, isNot(turn.sid));
        // Not running at the answer: the continuation starts after it.
        expect(resumed['running'], false);
        final auto = resumed['auto_continue'] as Map<String, Object?>;
        expect(auto['attempt'], 1);
        expect(auto['interrupted_at'], isA<num>());

        // It is a turn nobody here submitted, streamed to this socket.
        await back.until(
          () => back.types(next).contains('tool.start'),
          'the continuation turn to run its tool',
        );
        expect(back.types(next), contains('message.start'));
        final stopped = await back.rpc.request('session.interrupt', {
          'session_id': next,
        });
        expect(stopped['status'], 'interrupted');
        await back.until(
          () => back.types(next).contains('message.complete'),
          'the stopped continuation to complete',
          within: const Duration(seconds: 30),
        );
      },
      skip: restartSkip,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

/// A chat the test started: its runtime id, its stored id and the highest seq
/// seen when the tool call began.
class _Turn {
  const _Turn({required this.sid, required this.stored, required this.lastSeq});

  final String sid;
  final String stored;
  final int lastSeq;
}

/// A gateway connection that keeps the events it receives.
class _Tap {
  _Tap(this.rpc) {
    _subscription = rpc.events.listen(_events.add);
  }

  final GatewayRpcClient rpc;
  final _events = <GatewayEvent>[];
  late final StreamSubscription<GatewayEvent> _subscription;

  List<String> types(String sid) => [
    for (final e in _events)
      if (e.sessionId == sid) e.type,
  ];

  List<int> seqs(String sid) => [
    for (final e in _events)
      if (e.sessionId == sid && e.seq != null) e.seq!,
  ];

  int lastSeq(String sid) => seqs(sid).fold(0, (a, b) => b > a ? b : a);

  Future<void> until(
    bool Function() condition,
    String what, {
    Duration within = const Duration(seconds: 60),
  }) async {
    final deadline = DateTime.now().add(within);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await rpc.close();
  }
}

/// An OpenAI-compatible model that answers a prompt holding `[[sleep=N]]`
/// with one `terminal` call that sleeps N seconds (timeout raised past
/// Hermes' 180 s default), and everything else, the call's result and
/// Hermes' own side calls included, with a plain line.
Future<HttpServer> _serveSleepingModel() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    if (request.uri.path.endsWith('/models')) {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'object': 'list',
          'models': [
            {'key': 'scripted', 'type': 'llm'},
          ],
          'data': [
            {'id': 'scripted', 'object': 'model', 'context_length': 131072},
          ],
        }),
      );
      await response.close();
      return;
    }
    final raw = await utf8.decoder.bind(request).join();
    final decoded = raw.startsWith('{') ? jsonDecode(raw) : null;
    if (decoded is! Map<String, dynamic> || decoded['messages'] is! List) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final messages = (decoded['messages'] as List).cast<Map<String, dynamic>>();
    final userAt = messages.lastIndexWhere((m) => m['role'] == 'user');
    final userText = userAt < 0 ? '' : jsonEncode(messages[userAt]['content']);
    final stepsDone = messages
        .skip(userAt + 1)
        .where((m) => m['role'] == 'assistant')
        .length;
    final seconds = RegExp(r'\[\[sleep=(\d+)\]\]')
        .firstMatch(userText)
        ?.group(1);
    final callTool =
        decoded['tools'] != null && seconds != null && stepsDone == 0;
    final calls = [
      if (callTool)
        {
          'id': 'call_scripted',
          'type': 'function',
          'function': {
            'name': 'terminal',
            'arguments': jsonEncode({
              'command': 'sleep $seconds; echo woke',
              'timeout': 600,
            }),
          },
        },
    ];
    final content = callTool ? null : 'Scripted done.';
    final finish = callTool ? 'tool_calls' : 'stop';
    const usage = {
      'prompt_tokens': 10,
      'completion_tokens': 10,
      'total_tokens': 20,
    };
    if (decoded['stream'] != true) {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'id': 'chatcmpl-scripted',
          'object': 'chat.completion',
          'model': 'scripted',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': content,
                if (callTool) 'tool_calls': calls,
              },
              'finish_reason': finish,
            },
          ],
          'usage': usage,
        }),
      );
      await response.close();
      return;
    }
    response.headers.contentType = ContentType('text', 'event-stream');
    void chunk(Map<String, Object?> payload) => response.write(
      'data: ${jsonEncode({'id': 'chatcmpl-scripted', 'object': 'chat.completion.chunk', 'model': 'scripted', ...payload})}\n\n',
    );
    chunk({
      'choices': [
        {
          'index': 0,
          'delta': {
            'role': 'assistant',
            'content': content ?? '',
            if (callTool)
              'tool_calls': [
                for (final (i, call) in calls.indexed) {'index': i, ...call},
              ],
          },
          'finish_reason': null,
        },
      ],
    });
    chunk({
      'choices': [
        {'index': 0, 'delta': <String, Object?>{}, 'finish_reason': finish},
      ],
    });
    chunk({'choices': <Object?>[], 'usage': usage});
    response.write('data: [DONE]\n\n');
    await response.close();
  });
  return server;
}
