import 'dart:async';
import 'dart:math' show Random;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';

import '../support/fake_gateway.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
  });

  tearDown(() => transport.close());

  void plainReply(FakeGateway g, String sid) {
    g.event('message.start', sid);
    g.event('message.complete', sid, {'text': 'Hi', 'status': 'complete'});
  }

  Future<List<ChatEvent>> send({
    String? threadId,
    WorkspaceChoice? workspace,
    String? profile,
  }) => transport
      .send(
        threadId: threadId,
        profile: profile,
        text: 'hi',
        workspace: workspace,
      )
      .toList();

  Map<String, Object?> createParams() =>
      gateway.requestOf('session.create')['params']! as Map<String, Object?>;

  const picked = WorkspaceChoice(path: '/home/me/code/other');

  setUp(() => gateway.turn = plainReply);

  test(
    'a picked folder goes out as cwd and cwd_explicit on the create',
    () async {
      await send(workspace: picked, profile: 'work');

      expect(createParams(), {
        'profile': 'work',
        'source': 'hermes_app',
        'cwd': '/home/me/code/other',
        'cwd_explicit': true,
      });
    },
  );

  test('no pick sends neither field', () async {
    await send();

    expect(createParams().containsKey('cwd'), isFalse);
    expect(createParams().containsKey('cwd_explicit'), isFalse);
  });

  test('a resumed chat sends no folder, even with one given', () async {
    await send(threadId: 'stored-2', workspace: picked);

    final params = gateway.requestOf('session.resume')['params']! as Map;
    expect(params.containsKey('cwd'), isFalse);
    expect(params.containsKey('cwd_explicit'), isFalse);
    expect(gateway.methods, isNot(contains('session.create')));
  });

  test('a queued send never carries a folder', () async {
    // The queue interface has no folder parameter at all; a queued send of a
    // new chat is a send that never creates a session with a pick.
    final events = await transport
        .sendQueued(profile: 'work', text: 'hi', beforeSubmit: () async {})
        .toList();

    expect(events.first, isA<ThreadBound>());
    expect(createParams().containsKey('cwd'), isFalse);
    expect(createParams().containsKey('cwd_explicit'), isFalse);
  });

  test('info.cwd, branch and project come out as WorkspaceBound', () async {
    gateway.createResult = {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'info': {
        'cwd': '/home/me/code/other',
        'branch': 'main',
        'project': {
          'id': 'p_1',
          'slug': 'other',
          'name': 'Other',
          'primary_path': '/home/me/code/other',
        },
      },
    };

    final events = await send(workspace: picked);

    expect(events[0], isA<ThreadBound>());
    final bound = events[1] as WorkspaceBound;
    expect(bound.cwd, '/home/me/code/other');
    expect(bound.branch, 'main');
    expect(bound.project?.name, 'Other');
    expect(bound.project?.id, 'p_1');
    expect(bound.project?.primaryPath, '/home/me/code/other');
    expect(bound.retriedWithoutExplicit, isFalse);
  });

  test('a create that reports no folder emits no WorkspaceBound', () async {
    gateway.createResult = {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'info': {'model': 'm'},
    };

    final events = await send(workspace: picked);

    expect(events.whereType<WorkspaceBound>(), isEmpty);
  });

  test(
    'a 4000 naming cwd_explicit retries the create once without it',
    () async {
      var creates = 0;
      gateway.handlers['session.create'] = (params) {
        creates++;
        if (params.containsKey('cwd_explicit')) {
          throw const FakeRpcError(
            4000,
            'unknown params for session.create: cwd_explicit',
          );
        }
        return {
          'session_id': 'rt-1',
          'stored_session_id': 'stored-1',
          'info': {'cwd': '/home/me'},
        };
      };

      final events = await send(workspace: picked);

      expect(creates, 2);
      final creating = [
        for (final r in gateway.requests)
          if (r['method'] == 'session.create') r['params']! as Map,
      ];
      expect(creating[0]['cwd_explicit'], isTrue);
      expect(creating[1].containsKey('cwd_explicit'), isFalse);
      expect(creating[1]['cwd'], '/home/me/code/other');
      expect(events.whereType<ThreadBound>(), hasLength(1));
      final bound = events.whereType<WorkspaceBound>().single;
      expect(bound.retriedWithoutExplicit, isTrue);
      expect(bound.cwd, '/home/me');
    },
  );

  test('a 4000 that does not name cwd_explicit is not retried', () async {
    var creates = 0;
    gateway.handlers['session.create'] = (params) {
      creates++;
      throw const FakeRpcError(4000, 'bad request');
    };

    await expectLater(send(workspace: picked), throwsA(anything));

    expect(creates, 1);
  });

  test('a second 4000 after the retry fails the send', () async {
    var creates = 0;
    gateway.handlers['session.create'] = (params) {
      creates++;
      throw const FakeRpcError(4000, 'cwd_explicit is not known');
    };

    await expectLater(send(workspace: picked), throwsA(anything));

    expect(creates, 2);
  });

  test('the create is still tried 3 times when the socket will not open', () {
    fakeAsync((async) {
      var opened = 0;
      final stuck = HermesGatewayTransport(
        random: _Fixed(),
        sleep: (_) async {},
        connect: () async {
          opened++;
          throw StateError('network down');
        },
      );
      Object? error;
      stuck
          .send(text: 'hi', workspace: picked)
          .listen((_) {}, onError: (Object e) => error = e);
      async.elapse(const Duration(seconds: 5));

      expect(opened, 3);
      expect(error, isA<StateError>());
      unawaited(stuck.close());
    });
  });
  test('a flag dropped in one attempt does not leak into the next', () {
    fakeAsync((async) {
      final fresh = FakeGateway()
        ..stampSeq = true
        ..sendReady = true;
      final retrying = HermesGatewayTransport(
        connect: fresh.connect,
        random: _Fixed(),
      );
      var explicit = 0;
      fresh.handlers['session.create'] = (params) {
        explicit++;
        if (explicit == 1) {
          // The retry without the flag reaches a socket that never answers.
          fresh.silent.add('session.create');
          throw const FakeRpcError(4000, 'unknown param cwd_explicit');
        }
        return {
          'session_id': 'rt-1',
          'stored_session_id': 'stored-1',
          'info': {'cwd': '/home/me/code/other'},
        };
      };
      fresh.turn = plainReply;
      final seen = <ChatEvent>[];
      Object? error;
      retrying
          .send(text: 'hi', workspace: picked)
          .listen(seen.add, onError: (Object e) => error = e);

      async.elapse(const Duration(seconds: 30));
      fresh.silent.clear();
      async.elapse(const Duration(seconds: 5));

      expect(error, isNull);
      final creates = [
        for (final r in fresh.requests)
          if (r['method'] == 'session.create') r['params']! as Map,
      ];
      expect(creates.map((c) => c.containsKey('cwd_explicit')), [
        true,
        false,
        true,
      ]);
      final bound = seen.whereType<WorkspaceBound>().single;
      expect(bound.retriedWithoutExplicit, isFalse);
      unawaited(retrying.close());
    });
  });
}

class _Fixed implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;
}
