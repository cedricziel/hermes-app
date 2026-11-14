import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';

import '../support/fake_gateway.dart';

final _hash = 'a' * 40;

/// A transport whose chat `stored-1` owns the runtime `rt-1`.
Future<(FakeGateway, HermesGatewayTransport, OwnedSessionBinding)> _open({
  Duration longTimeout = const Duration(seconds: 90),
}) async {
  final gateway = FakeGateway();
  gateway.turn = (g, sid) =>
      g.event('message.complete', sid, {'text': 'Done', 'status': 'complete'});
  final transport = HermesGatewayTransport(
    connect: gateway.connect,
    longTimeout: longTimeout,
    readTimeout: const Duration(milliseconds: 200),
  );
  addTearDown(transport.close);
  final events = await transport.send(text: 'Test', profile: 'work').toList();
  final stored = events.whereType<ThreadBound>().single.threadId;
  return (
    gateway,
    transport,
    transport.ownedSessionFor(stored, profile: 'work')!,
  );
}

List<Map<String, Object?>> _calls(FakeGateway gateway, String method) => [
  for (final request in gateway.requests)
    if (request['method'] == method) request,
];

void main() {
  group('rollback.list', () {
    test('reads the owned runtime with the profile, never resuming', () async {
      final (gateway, transport, binding) = await _open();
      gateway.handlers['rollback.list'] = (_) => {
        'enabled': true,
        'checkpoints': [
          {
            'hash': _hash,
            'timestamp': '2026-09-29T10:00:00+00:00',
            'message': 'before patch',
          },
        ],
      };
      final resumes = gateway.methods
          .where((m) => m == 'session.resume')
          .length;
      final list = await transport.listCheckpoints(binding) as CheckpointsOn;
      expect(list.checkpoints.single.hash, _hash);
      expect(_calls(gateway, 'rollback.list').single['params'], {
        'session_id': 'rt-1',
        'profile': 'work',
      });
      expect(
        gateway.methods.where((m) => m == 'session.resume'),
        hasLength(resumes),
      );
    });

    test('off, method not found, 4001 and a server error', () async {
      final (gateway, transport, binding) = await _open();
      gateway.handlers['rollback.list'] = (_) => {
        'enabled': false,
        'checkpoints': [],
      };
      expect(await transport.listCheckpoints(binding), isA<CheckpointsOff>());
      gateway.handlers['rollback.list'] = (_) =>
          throw const FakeRpcError(-32601);
      expect(
        await transport.listCheckpoints(binding),
        isA<CheckpointsUnsupported>(),
      );
      gateway.handlers['rollback.list'] = (_) =>
          throw const FakeRpcError(4001, 'session not found');
      expect(
        (await transport.listCheckpoints(binding) as CheckpointsFailed).kind,
        CheckpointFailureKind.sessionGone,
      );
      gateway.handlers['rollback.list'] = (_) =>
          throw const FakeRpcError(5020, '/home/u/x boom');
      expect(
        (await transport.listCheckpoints(binding) as CheckpointsFailed).kind,
        CheckpointFailureKind.other,
      );
    });

    test('no answer ends as a failed read and the socket stays open', () async {
      final (gateway, transport, binding) = await _open();
      gateway.silent.add('rollback.list');
      expect(
        (await transport.listCheckpoints(binding) as CheckpointsFailed).kind,
        CheckpointFailureKind.transport,
      );
      gateway.silent.clear();
      gateway.handlers['rollback.list'] = (_) => {
        'enabled': true,
        'checkpoints': [],
      };
      expect(await transport.listCheckpoints(binding), isA<CheckpointsOn>());
    });

    test('a binding that lost its connection is not read', () async {
      final (gateway, transport, binding) = await _open();
      await transport.close();
      expect(
        await transport.listCheckpoints(binding),
        isA<CheckpointsFailed>(),
      );
      expect(_calls(gateway, 'rollback.list'), isEmpty);
    });

    test(
      'a stored chat without a runtime resumes only on the explicit call',
      () async {
        final gateway = FakeGateway();
        gateway.handlers['rollback.list'] = (_) => {
          'enabled': true,
          'checkpoints': [],
        };
        final transport = HermesGatewayTransport(connect: gateway.connect);
        addTearDown(transport.close);
        expect(transport.ownedSessionFor('stored-9', profile: 'work'), isNull);
        expect(gateway.requests, isEmpty);
        final list = await transport.listCheckpointsResuming(
          'stored-9',
          profile: 'work',
        );
        expect(list, isA<CheckpointsOn>());
        expect(gateway.methods, contains('session.resume'));
      },
    );
  });

  group('rollback.diff', () {
    test('sends the full hash and parses the answer', () async {
      final (gateway, transport, binding) = await _open();
      gateway.handlers['rollback.diff'] = (_) => {
        'stat': ' a.txt | 2 +-\n',
        'diff': 'diff --git a/a.txt b/a.txt\n@@ -1 +1 @@\n-x\n+y\n',
        'rendered': '\x1b[31mred',
      };
      final changes =
          await transport.checkpointChanges(binding, _hash) as Changes;
      expect(changes.files.single.path, 'a.txt');
      expect(_calls(gateway, 'rollback.diff').single['params'], {
        'session_id': 'rt-1',
        'profile': 'work',
        'hash': _hash,
      });
    });

    test(
      'empty answer is unreadable; container refusal is its own result',
      () async {
        final (gateway, transport, binding) = await _open();
        gateway.handlers['rollback.diff'] = (_) => {'stat': '', 'diff': ''};
        expect(
          await transport.checkpointChanges(binding, _hash),
          isA<ChangesUnreadable>(),
        );
        gateway.handlers['rollback.diff'] = (_) => throw const FakeRpcError(
          5022,
          'Checkpoints are not taken for terminal.backend=docker: file paths belong to the container, not this host.',
        );
        expect(
          await transport.checkpointChanges(binding, _hash),
          isA<ChangesRefused>(),
        );
      },
    );
  });

  group('rollback.restore', () {
    test('a full restore sends no file_path and reports the rewind', () async {
      final (gateway, transport, _) = await _open();
      gateway.handlers['rollback.restore'] = (_) => {
        'success': true,
        'restored_to': 'aaaaaaaa',
        'directory': '/home/u/proj',
        'history_removed': 3,
      };
      final result = await transport.restoreCheckpoint(
        'stored-1',
        profile: 'work',
        hash: _hash,
      );
      expect((result as Restored).historyRemoved, 3);
      expect(_calls(gateway, 'rollback.restore').single['params'], {
        'session_id': 'rt-1',
        'profile': 'work',
        'hash': _hash,
      });
    });

    test('a file restore sends the path and leaves the chat alone', () async {
      final (gateway, transport, _) = await _open();
      gateway.handlers['rollback.restore'] = (_) => {'success': true};
      final result = await transport.restoreCheckpoint(
        'stored-1',
        profile: 'work',
        hash: _hash,
        filePath: 'lib/a.dart',
      );
      expect((result as Restored).historyRemoved, 0);
      expect(
        _calls(gateway, 'rollback.restore').single['params'],
        containsPair('file_path', 'lib/a.dart'),
      );
    });

    test('success:false answers say whether files may have changed', () async {
      final (gateway, transport, _) = await _open();
      Future<CheckpointRestore> restore(String error) async {
        gateway.handlers['rollback.restore'] = (_) => {
          'success': false,
          'error': error,
        };
        return transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        );
      }

      expect(
        (await restore("Checkpoint 'abc' not found") as RestoreRefused).kind,
        CheckpointFailureKind.notFound,
      );
      expect(
        (await restore(
          'No checkpoints exist for this directory',
        ) as RestoreRefused).kind,
        CheckpointFailureKind.notFound,
      );
      expect(
        (await restore(
          'Checkpoint contains nested git repositories that were not captured (a/); rollback was not performed',
        ) as RestoreRefused).kind,
        CheckpointFailureKind.nestedRepositories,
      );
      expect(
        (await restore(
          'Checkpoints are not taken for terminal.backend=docker: x',
        ) as RestoreRefused).kind,
        CheckpointFailureKind.container,
      );
      expect(
        (await restore(
          'File path escapes the working directory via traversal',
        ) as RestoreRefused).kind,
        CheckpointFailureKind.pathRejected,
      );
      for (final error in [
        'Restore failed: git said /home/u/x',
        'checkpoint store is busy: /x',
        'something else',
      ]) {
        final failed = await restore(error) as RestoreFailed;
        expect(failed.filesPossiblyChanged, isTrue, reason: error);
      }
    });

    test('4009 splits a running compress from a running reply', () async {
      final (gateway, transport, _) = await _open();
      gateway.handlers['rollback.restore'] = (_) => throw const FakeRpcError(
        4009,
        'session busy — a /compress is running',
      );
      expect(
        (await transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        ) as RestoreBusy).reason,
        CheckpointBusyReason.compressing,
      );
      gateway.handlers['rollback.restore'] = (_) =>
          throw const FakeRpcError(4009, 'session busy — agent running');
      expect(
        (await transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        ) as RestoreBusy).reason,
        CheckpointBusyReason.replying,
      );
    });

    test('5021 splits a failed rewind from any other failure', () async {
      final (gateway, transport, _) = await _open();
      gateway.handlers['rollback.restore'] = (_) => throw const FakeRpcError(
        5021,
        'checkpoint restored, but session history rewind failed: boom',
      );
      expect(
        await transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        ),
        isA<RestoredHistoryNotRewound>(),
      );
      gateway.handlers['rollback.restore'] = (_) =>
          throw const FakeRpcError(5021, 'KeyError: /home/u/x');
      expect(
        (await transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        ) as RestoreFailed).filesPossiblyChanged,
        isTrue,
      );
    });

    test('4001 and method-not-found', () async {
      final (gateway, transport, _) = await _open();
      gateway.handlers['rollback.restore'] = (_) =>
          throw const FakeRpcError(4001, 'session not found');
      expect(
        (await transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        ) as RestoreFailed).kind,
        CheckpointFailureKind.sessionGone,
      );
      gateway.handlers['rollback.restore'] = (_) =>
          throw const FakeRpcError(-32601);
      expect(
        await transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        ),
        isA<RestoreUnsupported>(),
      );
    });

    test(
      'a lost answer ends as may-have-happened and is never resent',
      () async {
        final (gateway, transport, _) = await _open(
          longTimeout: const Duration(milliseconds: 100),
        );
        gateway.silent.add('rollback.restore');
        expect(
          await transport.restoreCheckpoint(
            'stored-1',
            profile: 'work',
            hash: _hash,
          ),
          isA<RestoreMayHaveHappened>(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(_calls(gateway, 'rollback.restore'), hasLength(1));
      },
    );

    test(
      'a dropped connection ends as may-have-happened and is never resent',
      () async {
        final (gateway, transport, _) = await _open();
        gateway.silent.add('rollback.restore');
        final pending = transport.restoreCheckpoint(
          'stored-1',
          profile: 'work',
          hash: _hash,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        gateway.drop();
        expect(await pending, isA<RestoreMayHaveHappened>());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(_calls(gateway, 'rollback.restore'), hasLength(1));
      },
    );
  });

  group('session.context_breakdown', () {
    test('reads the owned runtime and parses', () async {
      final (gateway, transport, binding) = await _open();
      gateway.handlers['session.context_breakdown'] = (_) => {
        'categories': [
          {'id': 'conversation', 'tokens': 90},
          {'id': 'rules', 'tokens': 120},
        ],
        'context_used': 210,
        'context_max': 1000,
        'context_percent': 21,
        'model': 'm',
      };
      final result = await transport.contextBreakdown(binding) as Breakdown;
      expect(result.categories.first.kind, ContextCategoryKind.rules);
      expect(_calls(gateway, 'session.context_breakdown').single['params'], {
        'session_id': 'rt-1',
        'profile': 'work',
      });
    });

    test('unsupported, failed and unanswered', () async {
      final (gateway, transport, binding) = await _open();
      gateway.handlers['session.context_breakdown'] = (_) =>
          throw const FakeRpcError(-32601);
      expect(
        await transport.contextBreakdown(binding),
        isA<BreakdownUnsupported>(),
      );
      gateway.handlers['session.context_breakdown'] = (_) =>
          throw const FakeRpcError(5000, 'Could not compute context breakdown');
      expect(await transport.contextBreakdown(binding), isA<BreakdownFailed>());
      gateway.handlers.remove('session.context_breakdown');
      gateway.silent.add('session.context_breakdown');
      expect(await transport.contextBreakdown(binding), isA<BreakdownFailed>());
    });
  });

  group('session.compress', () {
    test('sends the focus only when there is one', () async {
      final (gateway, transport, _) = await _open();
      gateway.handlers['session.compress'] = (_) => {
        'status': 'compressed',
        'before_messages': 42,
        'after_messages': 9,
      };
      final plain = await transport.compressSession(
        'stored-1',
        profile: 'work',
        focus: '  ',
      );
      expect((plain as Compressed).beforeMessages, 42);
      await transport.compressSession(
        'stored-1',
        profile: 'work',
        focus: 'the schema',
      );
      final calls = _calls(gateway, 'session.compress');
      expect(calls[0]['params'], {'session_id': 'rt-1', 'profile': 'work'});
      expect(calls[1]['params'], {
        'session_id': 'rt-1',
        'profile': 'work',
        'focus_topic': 'the schema',
      });
    });

    test('a focus the server would read as a command is never sent', () async {
      final (gateway, transport, _) = await _open();
      for (final focus in ['--preview the schema', 'Here 3', 'up to here']) {
        await expectLater(
          transport.compressSession('stored-1', profile: 'work', focus: focus),
          throwsArgumentError,
        );
      }
      expect(_calls(gateway, 'session.compress'), isEmpty);
    });

    test('busy, unsupported and failed answers', () async {
      final (gateway, transport, _) = await _open();
      gateway.handlers['session.compress'] = (_) => throw const FakeRpcError(
        4009,
        'session busy — a /compress is running',
      );
      expect(
        (await transport.compressSession(
          'stored-1',
          profile: 'work',
        ) as CompressBusy).reason,
        CheckpointBusyReason.compressing,
      );
      gateway.handlers['session.compress'] = (_) =>
          throw const FakeRpcError(4009, 'session busy — agent running');
      expect(
        (await transport.compressSession(
          'stored-1',
          profile: 'work',
        ) as CompressBusy).reason,
        CheckpointBusyReason.replying,
      );
      gateway.handlers['session.compress'] = (_) =>
          throw const FakeRpcError(-32601);
      expect(
        await transport.compressSession('stored-1', profile: 'work'),
        isA<CompressUnsupported>(),
      );
      gateway.handlers['session.compress'] = (_) =>
          throw const FakeRpcError(5005, 'boom /home/u');
      expect(
        await transport.compressSession('stored-1', profile: 'work'),
        isA<CompressFailed>(),
      );
    });

    test(
      'a lost answer ends as may-have-happened and is never resent',
      () async {
        final (gateway, transport, _) = await _open(
          longTimeout: const Duration(milliseconds: 100),
        );
        gateway.silent.add('session.compress');
        expect(
          await transport.compressSession('stored-1', profile: 'work'),
          isA<CompressMayHaveHappened>(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(_calls(gateway, 'session.compress'), hasLength(1));
      },
    );

    test('a dropped connection ends as may-have-happened', () async {
      final (gateway, transport, _) = await _open();
      gateway.silent.add('session.compress');
      final pending = transport.compressSession('stored-1', profile: 'work');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      gateway.drop();
      expect(await pending, isA<CompressMayHaveHappened>());
      expect(_calls(gateway, 'session.compress'), hasLength(1));
    });
  });
}
