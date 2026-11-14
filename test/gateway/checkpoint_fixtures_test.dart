import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';

import '../support/fake_gateway.dart';

/// The recorded shapes in `test/fixtures/gateway/`, fed through the
/// transport's own parsers.
Map<String, Object?> _cases(String file) =>
    (jsonDecode(File('test/fixtures/gateway/$file').readAsStringSync())
            as Map<String, Object?>)['cases']!
        as Map<String, Object?>;

final _hash = '1a2b3c4d' * 5;

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late OwnedSessionBinding binding;
  late String stored;

  setUp(() async {
    gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Done',
      'status': 'complete',
    });
    transport = HermesGatewayTransport(connect: gateway.connect);
    final events = await transport.send(text: 'Test', profile: 'work').toList();
    stored = events.whereType<ThreadBound>().single.threadId;
    binding = transport.ownedSessionFor(stored, profile: 'work')!;
  });
  tearDown(() => transport.close());

  /// Answers [method] with the fixture case: its result, or its error.
  void answer(String method, Object? fixture) {
    final entry = fixture! as Map<String, Object?>;
    gateway.handlers[method] = (_) {
      final error = entry['error'];
      if (error is Map) {
        throw FakeRpcError(error['code']! as int, error['message']! as String);
      }
      return entry['result']! as Map<String, Object?>;
    };
  }

  test('rollback.list: on, off and empty', () async {
    final cases = _cases('rollback_list.json');
    answer('rollback.list', cases['on']);
    final on = await transport.listCheckpoints(binding) as CheckpointsOn;
    expect(on.checkpoints.map((c) => c.reason), [
      CheckpointReason.beforeRestore,
      CheckpointReason.beforeEdit,
      CheckpointReason.beforeEdit,
      CheckpointReason.beforeEdit,
    ]);
    expect(on.checkpoints.first.restoredFrom, _hash.substring(0, 8));
    expect(on.checkpoints.last.timestamp, DateTime.utc(2026, 9, 29, 10));
    answer('rollback.list', cases['nested_repository']);
    final nested = await transport.listCheckpoints(binding) as CheckpointsOn;
    expect(nested.checkpoints.single.reason, CheckpointReason.beforeEdit);
    answer('rollback.list', cases['off']);
    expect(await transport.listCheckpoints(binding), isA<CheckpointsOff>());
    answer('rollback.list', cases['empty']);
    expect(
      (await transport.listCheckpoints(binding) as CheckpointsOn).checkpoints,
      isEmpty,
    );
  });

  test('rollback.diff: normal, cut at 4,000 and empty', () async {
    final cases = _cases('rollback_diff.json');
    answer('rollback.diff', cases['normal']);
    final normal = await transport.checkpointChanges(binding, _hash) as Changes;
    expect(normal.files.map((f) => f.path), ['notes.md']);
    expect(normal.truncated, isFalse);
    expect(normal.files.every((f) => f.diff != null), isTrue);

    answer('rollback.diff', cases['cut_at_4000']);
    final cut = await transport.checkpointChanges(binding, _hash) as Changes;
    expect(cut.truncated, isTrue);
    expect(cut.files.map((f) => f.path), ['long.md', 'notes.md']);

    answer('rollback.diff', cases['empty']);
    expect(
      await transport.checkpointChanges(binding, _hash),
      isA<ChangesUnreadable>(),
    );

    answer('rollback.diff', cases['container']);
    expect(
      await transport.checkpointChanges(binding, _hash),
      isA<ChangesRefused>(),
    );
    answer('rollback.diff', cases['index_out_of_range']);
    expect(
      await transport.checkpointChanges(binding, _hash),
      isA<ChangesFailed>(),
    );
  });

  test(
    'rollback.restore: success, each refusal, 4009 and both 5021s',
    () async {
      final cases = _cases('rollback_restore.json');
      Future<CheckpointRestore> restore(String name) {
        answer('rollback.restore', cases[name]);
        return transport.restoreCheckpoint(
          stored,
          profile: 'work',
          hash: _hash,
        );
      }

      final restored = await restore('success_history_removed') as Restored;
      expect(restored.historyRemoved, 6);
      expect(((await restore('success_file')) as Restored).historyRemoved, 0);
      for (final (name, kind) in [
        ('no_checkpoints', CheckpointFailureKind.notFound),
        ('not_found', CheckpointFailureKind.notFound),
        ('path_escapes', CheckpointFailureKind.pathRejected),
        ('absolute_path', CheckpointFailureKind.pathRejected),
        ('matched_no_files', CheckpointFailureKind.pathRejected),
        ('nested_repositories', CheckpointFailureKind.nestedRepositories),
        ('container', CheckpointFailureKind.container),
      ]) {
        final result = await restore(name);
        expect(result, isA<RestoreRefused>(), reason: name);
        expect((result as RestoreRefused).kind, kind, reason: name);
      }
      for (final (name, kind) in [
        ('restore_failed', CheckpointFailureKind.other),
        ('store_busy', CheckpointFailureKind.storeBusy),
        ('failed_5021', CheckpointFailureKind.other),
      ]) {
        final result = await restore(name) as RestoreFailed;
        expect(result.kind, kind, reason: name);
        expect(result.filesPossiblyChanged, isTrue, reason: name);
      }
      expect(
        (await restore('busy_4009') as RestoreBusy).reason,
        CheckpointBusyReason.replying,
      );
      final noHash = await restore('hash_required_4014') as RestoreFailed;
      expect(noHash.filesPossiblyChanged, isFalse);
      expect(
        await restore('history_not_rewound_5021'),
        isA<RestoredHistoryNotRewound>(),
      );
    },
  );

  test('session.compress: every recorded answer', () async {
    final cases = _cases('session_compress.json');
    Future<CompressionResult> compress(String name) {
      answer('session.compress', cases[name]);
      return transport.compressSession(stored, profile: 'work');
    }

    final compressed = await compress('compressed') as Compressed;
    expect(compressed.beforeMessages, 36);
    expect(compressed.afterMessages, 24);
    expect(compressed.beforeTokens, 16585);
    expect(compressed.afterTokens, 15767);
    expect(compressed.fallbackUsed, isFalse);
    expect(await compress('noop'), isA<NothingToCompress>());
    expect(await compress('aborted'), isA<CompressionAborted>());
    expect(await compress('refused_would_grow'), isA<WouldNotShrink>());
    expect(await compress('refused_with_fallback'), isA<WouldNotShrink>());
    expect(
      (await compress('fallback_used') as Compressed).fallbackUsed,
      isTrue,
    );
    expect(await compress('lock_held'), isA<CompressLockHeld>());
    expect(await compress('pending'), isA<CompressPending>());
    expect(
      (await compress('busy_while_compressing_4009') as CompressBusy).reason,
      CheckpointBusyReason.compressing,
    );
    expect(
      (await compress('busy_while_replying_4009') as CompressBusy).reason,
      CheckpointBusyReason.replying,
    );
  });

  test('session.context_breakdown: seven and eight categories, and none before '
      'the agent is built', () async {
    final cases = _cases('session_context_breakdown.json');
    answer('session.context_breakdown', cases['eight_categories']);
    final full = await transport.contextBreakdown(binding) as Breakdown;
    expect(full.categories, hasLength(8));
    expect(full.categories.first.kind, ContextCategoryKind.conversation);
    expect(
      full.categories.map((c) => c.kind),
      isNot(contains(ContextCategoryKind.other)),
    );
    expect(full.used, 28500);
    expect(full.max, 200000);
    expect(full.percent, 14);
    expect(full.estimated, isTrue);
    expect(full.source, ContextSource.providerUsagePlusEstimate);

    answer('session.context_breakdown', cases['seven_categories']);
    final seven = await transport.contextBreakdown(binding) as Breakdown;
    expect(seven.categories, hasLength(7));
    expect(
      seven.categories.map((c) => c.kind),
      isNot(contains(ContextCategoryKind.other)),
    );
    expect(seven.categories.first.kind, ContextCategoryKind.toolDefinitions);
    expect(seven.source, ContextSource.providerUsage);
    expect(seven.estimated, isFalse);
    expect(seven.model, 'example-model');

    answer('session.context_breakdown', cases['above_85_percent']);
    final high = await transport.contextBreakdown(binding) as Breakdown;
    expect(high.percent, inInclusiveRange(85, 100));

    answer('session.context_breakdown', cases['after_compress']);
    final after = await transport.contextBreakdown(binding) as Breakdown;
    expect(after.source, ContextSource.localEstimate);
    expect(after.used, isNotNull);

    answer('session.context_breakdown', cases['before_agent_build']);
    final empty = await transport.contextBreakdown(binding) as Breakdown;
    expect(empty.categories, isEmpty);
    expect(empty.estimatedTotal, 0);
    expect(empty.model, isNull);
  });
}
