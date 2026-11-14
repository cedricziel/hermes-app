import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/checkpoints/action_telemetry.dart';
import 'package:hermes_app/src/chat/checkpoints/chat_action_bridge.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_controller.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_checkpoints_transport.dart';
import '../../support/recording_tracer.dart';

final _h1 = 'a1' * 20, _h2 = 'b2' * 20, _h3 = 'c3' * 20;

Checkpoint _cp(
  String hash, {
  CheckpointReason reason = CheckpointReason.beforeEdit,
  String? from,
}) => Checkpoint(
  hash: hash,
  reason: reason,
  restoredFrom: from,
  timestamp: DateTime.utc(2026, 9, 29),
);

const _fileA = ChangedFile(path: 'a.txt', restorable: true, changes: 2);
const _weird = ChangedFile(path: '[x].txt', changes: 1);

class _Setup {
  _Setup({bool live = true, ActionTelemetry? telemetry}) {
    controller = CheckpointsController(
      transport: transport,
      bridge: chat.bridge,
      telemetry: telemetry ?? const ActionTelemetry(),
    )..bind(fakeScope(live: live));
    addTearDown(controller.dispose);
  }
  final transport = FakeCheckpointsTransport();
  final chat = FakeChatBridge();
  late final CheckpointsController controller;

  /// A panel that listed [_h1] and [_h2] and opened [_h1]'s changes.
  Future<void> openWithChanges({
    List<ChangedFile> files = const [_fileA],
  }) async {
    transport.list = CheckpointsOn([_cp(_h1), _cp(_h2)]);
    transport.changes = Changes(files, truncated: false);
    await controller.panelOpened();
    await controller.openChanges(_h1);
  }
}

void main() {
  group('reads', () {
    test('the list loads when the panel opens and after a turn only while it is open', () async {
      final s = _Setup();
      s.transport.list = CheckpointsOn([_cp(_h1)]);
      await s.controller.turnEnded();
      expect(s.transport.count('list'), 0);
      await s.controller.panelOpened();
      expect(s.transport.count('list'), 1);
      expect(s.controller.rowState, CheckpointsRowState.count);
      expect(s.controller.count, 1);
      await s.controller.turnEnded();
      expect(s.transport.count('list'), 2);
      s.controller.panelClosed();
      await s.controller.turnEnded();
      expect(s.transport.count('list'), 2);
    });

    test(
      'a stored chat without a session is not checked until opened on purpose',
      () async {
        final s = _Setup(live: false);
        expect(s.controller.rowState, CheckpointsRowState.notChecked);
        await s.controller.panelOpened();
        await s.controller.refresh();
        expect(s.transport.calls, isEmpty);
        s.transport.list = CheckpointsOn([_cp(_h1)]);
        await s.controller.openResuming();
        expect(s.transport.calls, ['listResuming']);
        expect(s.controller.rowState, CheckpointsRowState.count);
      },
    );

    test(
      'off shows a row only when the chat ran an edit; old servers show none',
      () async {
        final s = _Setup();
        s.transport.list = const CheckpointsOff();
        await s.controller.panelOpened();
        expect(s.controller.rowState, CheckpointsRowState.hidden);
        s.chat.hasEdits = true;
        expect(s.controller.rowState, CheckpointsRowState.off);
        s.transport.list = const CheckpointsUnsupported();
        await s.controller.refresh();
        expect(s.controller.rowState, CheckpointsRowState.hidden);
      },
    );

    test('a failed read is a row that can be tried again', () async {
      final s = _Setup();
      s.transport.list = const CheckpointsFailed(CheckpointFailureKind.other);
      await s.controller.panelOpened();
      expect(s.controller.rowState, CheckpointsRowState.failed);
      s.transport.list = CheckpointsOn([_cp(_h1)]);
      await s.controller.refresh();
      expect(s.controller.rowState, CheckpointsRowState.count);
    });

    test('a diff is read only for the checkpoint the user opens', () async {
      final s = _Setup();
      await s.openWithChanges();
      expect(s.transport.calls.where((c) => c.startsWith('changes')), [
        'changes:$_h1',
      ]);
      expect(s.controller.changes, isA<Changes>());
      s.controller.closeChanges();
      expect(s.controller.changes, isNull);
    });

    test('a late list answer after a scope change is dropped', () async {
      final s = _Setup();
      s.transport
        ..list = CheckpointsOn([_cp(_h1)])
        ..listGate = Completer<void>();
      final pending = s.controller.panelOpened();
      await Future<void>.delayed(Duration.zero);
      s.controller.bind(fakeScope(thread: 'stored-2'));
      s.transport.listGate!.complete();
      await pending;
      expect(s.controller.count, isNull);
      expect(s.controller.checkpoints, isEmpty);
    });

    test('a late diff answer after a scope change is dropped', () async {
      final s = _Setup();
      s.transport.list = CheckpointsOn([_cp(_h1)]);
      await s.controller.panelOpened();
      s.transport
        ..changes = const Changes([_fileA], truncated: false)
        ..changesGate = Completer<void>();
      final pending = s.controller.openChanges(_h1);
      await Future<void>.delayed(Duration.zero);
      s.controller.bind(null);
      s.transport.changesGate!.complete();
      await pending;
      expect(s.controller.changes, isNull);
    });

    test('App Lock drops the diff and the list, keeps only the count, and refuses restore', () async {
      final s = _Setup();
      await s.openWithChanges();
      s.controller.setLocked(true);
      expect(s.controller.changes, isNull);
      expect(s.controller.checkpoints, isEmpty);
      expect(s.controller.count, 2);
      expect(s.controller.restoreRefusal(), RestoreRefusal.locked);
      expect(s.controller.beginRestore(_h1), isNull);
      s.controller.setLocked(false);
      expect(
        s.controller.changes,
        isNull,
        reason: 'a dropped diff is not brought back',
      );
    });

    test(
      'disconnect keeps the values, marks them stale and refuses restore',
      () async {
        final s = _Setup();
        await s.openWithChanges();
        s.controller.disconnected();
        expect(s.controller.notUpToDate, isTrue);
        expect(s.controller.checkpoints, hasLength(2));
        expect(s.controller.beginRestore(_h1), isNull);
      },
    );

    test('sign-out discards everything', () async {
      final s = _Setup();
      await s.openWithChanges();
      s.controller.clear();
      expect(s.controller.checkpoints, isEmpty);
      expect(s.controller.changes, isNull);
      expect(s.controller.rowState, CheckpointsRowState.hidden);
    });
  });

  group('restore is sent only after confirmation, for what was chosen', () {
    test('starting a restore sends nothing; confirming sends once', () async {
      final s = _Setup();
      await s.openWithChanges();
      final intent = s.controller.beginRestore(_h1)!;
      expect(s.transport.count('restore'), 0);
      await s.controller.confirmRestore(intent);
      await s.controller.confirmRestore(intent);
      expect(s.transport.restoreRequests, [
        (thread: 'stored-1', profile: 'work', hash: _h1, file: null),
      ]);
    });

    test('a restore started in one chat is not sent after the controller moved to another', () async {
      final s = _Setup();
      await s.openWithChanges();
      final intent = s.controller.beginRestore(_h1)!;
      s.controller.bind(fakeScope(thread: 'stored-2'));
      await s.controller.confirmRestore(intent);
      expect(s.transport.count('restore'), 0);
    });

    test('a hash that is not in the list cannot be restored', () async {
      final s = _Setup();
      await s.openWithChanges();
      expect(s.controller.beginRestore(_h3), isNull);
    });

    test('a full restore waits for the reply; a file restore goes ahead with a warning', () async {
      final s = _Setup();
      await s.openWithChanges();
      s.chat.replying = true;
      expect(s.controller.restoreRefusal(), RestoreRefusal.replying);
      expect(s.controller.beginRestore(_h1), isNull);
      final file = s.controller.beginRestore(_h1, filePath: 'a.txt')!;
      expect(file.agentWorking, isTrue);
      await s.controller.confirmRestore(file);
      expect(s.transport.restoreRequests.single.file, 'a.txt');
    });

    test(
      'a reply that started after the confirmation opened stops a full restore',
      () async {
        final s = _Setup();
        await s.openWithChanges();
        final intent = s.controller.beginRestore(_h1)!;
        s.chat.replying = true;
        await s.controller.confirmRestore(intent);
        expect(s.transport.count('restore'), 0);
        expect(s.chat.held, isEmpty);
      },
    );

    test(
      'only a restorable path read from this checkpoint stat is offered',
      () async {
        final s = _Setup();
        await s.openWithChanges(files: const [_fileA, _weird]);
        expect(s.controller.beginRestore(_h1, filePath: '[x].txt'), isNull);
        expect(s.controller.beginRestore(_h1, filePath: 'other.txt'), isNull);
        expect(s.controller.beginRestore(_h2, filePath: 'a.txt'), isNull);
        expect(s.controller.beginRestore(_h1, filePath: 'a.txt'), isNotNull);
      },
    );

    test('one restore at a time', () async {
      final s = _Setup();
      await s.openWithChanges();
      s.transport.restoreGate = Completer<void>();
      final first = s.controller.confirmRestore(
        s.controller.beginRestore(_h1)!,
      );
      await Future<void>.delayed(Duration.zero);
      expect(s.controller.restoring, isTrue);
      expect(s.controller.beginRestore(_h1), isNull);
      s.transport.restoreGate!.complete();
      await first;
      expect(s.controller.restoring, isFalse);
    });
  });

  group('a full restore holds Send until it settles', () {
    test(
      'held from confirmation, released on success, failure and a lost answer',
      () async {
        for (final result in <CheckpointRestore>[
          const Restored(historyRemoved: 1),
          const RestoreFailed(
            CheckpointFailureKind.other,
            filesPossiblyChanged: true,
          ),
          const RestoreMayHaveHappened(),
        ]) {
          final s = _Setup();
          await s.openWithChanges();
          s.transport
            ..restore = result
            ..restoreGate = Completer<void>();
          final pending = s.controller.confirmRestore(
            s.controller.beginRestore(_h1)!,
          );
          await Future<void>.delayed(Duration.zero);
          expect(s.controller.sendHeld, isTrue);
          expect(s.chat.held, [true]);
          s.transport.restoreGate!.complete();
          await pending;
          expect(s.controller.sendHeld, isFalse);
          expect(s.chat.held, [true, false], reason: '$result');
        }
      },
    );

    test('a file restore does not hold Send', () async {
      final s = _Setup();
      await s.openWithChanges();
      await s.controller.confirmRestore(
        s.controller.beginRestore(_h1, filePath: 'a.txt')!,
      );
      expect(s.chat.held, isEmpty);
    });

    test(
      'the hold is released if the controller goes away mid-restore',
      () async {
        final s = _Setup();
        await s.openWithChanges();
        s.transport.restoreGate = Completer<void>();
        final pending = s.controller.confirmRestore(
          s.controller.beginRestore(_h1)!,
        );
        await Future<void>.delayed(Duration.zero);
        s.controller.dispose();
        expect(s.chat.held, [true, false]);
        s.transport.restoreGate!.complete();
        await pending;
      },
    );
  });

  group('outcomes say only what is known', () {
    test('N is used only when read since the last turn ended', () async {
      final s = _Setup();
      await s.openWithChanges(
        files: const [
          _fileA,
          ChangedFile(path: 'b.txt', restorable: true),
        ],
      );
      final fresh = s.controller.beginRestore(_h1)!;
      expect(fresh.filesDiffer, 2);
      await s.controller.confirmRestore(fresh);
      expect(s.controller.outcome!.filesRestored, 2);

      final later = _Setup();
      await later.openWithChanges();
      await later.controller.turnEnded();
      final stale = later.controller.beginRestore(_h1)!;
      expect(stale.filesDiffer, isNull);
      await later.controller.confirmRestore(stale);
      expect(later.controller.outcome!.filesRestored, isNull);
    });

    test('one file restored is "1 file" and leaves the chat alone', () async {
      final s = _Setup();
      await s.openWithChanges();
      await s.controller.confirmRestore(
        s.controller.beginRestore(_h1, filePath: 'a.txt')!,
      );
      expect(s.controller.outcome!.filesRestored, 1);
      expect(s.chat.refetches, 1);
      expect(s.chat.handedBack, isEmpty);
      expect(
        s.controller.changes,
        isNotNull,
        reason: 'the Changes page is re-read',
      );
    });

    test('history_removed 0 claims nothing and hands nothing back', () async {
      final s = _Setup();
      s.chat.quote = const PromptQuote(
        messageId: 'm1',
        text: 'Split the token refresh out',
      );
      await s.openWithChanges();
      s.transport.restore = const Restored();
      await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
      expect(s.controller.outcome!.historyRemoved, 0);
      expect(s.chat.handedBack, isEmpty);
      expect(s.controller.outcome!.lastMessageNotRemoved, isFalse);
    });

    test('the quoted message goes to the composer only when the re-read chat no longer holds it', () async {
      final s = _Setup();
      s.chat.quote = const PromptQuote(
        messageId: 'm1',
        text: 'Split the token refresh out',
      );
      await s.openWithChanges();
      s.transport.restore = const Restored(historyRemoved: 3);
      await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
      expect(s.chat.handedBack, ['Split the token refresh out']);
      expect(s.chat.refetches, 1);

      final held = _Setup();
      held.chat
        ..quote = const PromptQuote(
          messageId: 'm1',
          text: 'Split the token refresh out',
        )
        ..quoteStillThere = true;
      await held.openWithChanges();
      held.transport.restore = const Restored(historyRemoved: 3);
      await held.controller.confirmRestore(held.controller.beginRestore(_h1)!);
      expect(held.chat.handedBack, isEmpty);
      expect(held.controller.outcome!.lastMessageNotRemoved, isTrue);
    });

    test('a new "Before a restore" checkpoint is claimed only for a new hash that restores to this one', () async {
      final s = _Setup();
      await s.openWithChanges();
      final restoredFrom = _h1.substring(0, 8);
      s.transport.restore = const Restored(historyRemoved: 1);
      s.transport.listQueue.add(
        CheckpointsOn([
          _cp(_h3, reason: CheckpointReason.beforeRestore, from: restoredFrom),
          _cp(_h1),
          _cp(_h2),
        ]),
      );
      await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
      expect(s.controller.outcome!.safetyCheckpoint, isTrue);
    });

    test(
      'an older "Before a restore" row at the top is not taken as the new one',
      () async {
        final s = _Setup();
        s.transport.list = CheckpointsOn([
          _cp(
            _h3,
            reason: CheckpointReason.beforeRestore,
            from: _h1.substring(0, 8),
          ),
          _cp(_h1),
        ]);
        s.transport.changes = const Changes([_fileA], truncated: false);
        await s.controller.panelOpened();
        await s.controller.openChanges(_h1);
        s.transport.restore = const Restored(historyRemoved: 1);
        await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
        expect(s.controller.outcome!.safetyCheckpoint, isFalse);
      },
    );

    test(
      'a new safety checkpoint for a different target is not claimed',
      () async {
        final s = _Setup();
        await s.openWithChanges();
        s.transport.restore = const Restored(historyRemoved: 1);
        s.transport.listQueue.add(
          CheckpointsOn([
            _cp(_h3, reason: CheckpointReason.beforeRestore, from: 'deadbeef'),
            _cp(_h1),
            _cp(_h2),
          ]),
        );
        await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
        expect(s.controller.outcome!.safetyCheckpoint, isFalse);
      },
    );

    test(
      'an unreadable re-list claims nothing about the safety checkpoint',
      () async {
        final s = _Setup();
        await s.openWithChanges();
        s.transport.restore = const Restored(historyRemoved: 1);
        s.transport.listQueue.add(
          const CheckpointsFailed(CheckpointFailureKind.transport),
        );
        await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
        expect(s.controller.outcome!.safetyCheckpoint, isNull);
      },
    );
  });

  group('failures', () {
    Future<_Setup> failing(CheckpointRestore result) async {
      final s = _Setup();
      await s.openWithChanges();
      s.transport.restore = result;
      await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
      return s;
    }

    test(
      'a lost answer is never shown as done, re-reads, and is not sent again',
      () async {
        final s = await failing(const RestoreMayHaveHappened());
        expect(s.controller.outcome!.kind, RestoreOutcomeKind.mayHaveHappened);
        expect(s.transport.count('restore'), 1);
        expect(s.chat.refetches, 1);
        expect(s.transport.count('list'), 2);
        // Offered again, behind a new confirmation: nothing is sent until then.
        final again = s.controller.beginRestore(_h1)!;
        expect(s.transport.count('restore'), 1);
        await s.controller.confirmRestore(again);
        expect(s.transport.count('restore'), 2);
      },
    );

    test(
      'history rewind failed: files restored, chat re-read, composer untouched',
      () async {
        final s = _Setup();
        s.chat.quote = const PromptQuote(messageId: 'm1', text: 'x');
        await s.openWithChanges();
        s.transport.restore = const RestoredHistoryNotRewound();
        await s.controller.confirmRestore(s.controller.beginRestore(_h1)!);
        expect(
          s.controller.outcome!.kind,
          RestoreOutcomeKind.historyNotRewound,
        );
        expect(s.chat.refetches, 1);
        expect(s.chat.handedBack, isEmpty);
      },
    );

    test('failures after the safety checkpoint say files may have changed and re-list', () async {
      final s = await failing(
        const RestoreFailed(
          CheckpointFailureKind.other,
          filesPossiblyChanged: true,
        ),
      );
      expect(s.controller.outcome!.kind, RestoreOutcomeKind.failedMaybeChanged);
      expect(s.chat.refetches, 1);
      expect(s.transport.count('list'), 2);
    });

    test('refusals before anything was touched say nothing changed', () async {
      final s = await failing(
        const RestoreRefused(CheckpointFailureKind.nestedRepositories),
      );
      expect(s.controller.outcome!.kind, RestoreOutcomeKind.refused);
      expect(
        s.controller.outcome!.refusal,
        CheckpointFailureKind.nestedRepositories,
      );
      expect(s.chat.refetches, 0);
    });

    test('a stale checkpoint re-lists', () async {
      final s = await failing(
        const RestoreRefused(CheckpointFailureKind.notFound),
      );
      expect(s.transport.count('list'), 2);
    });

    test('busy changes nothing', () async {
      var s = await failing(
        const RestoreBusy(CheckpointBusyReason.compressing),
      );
      expect(s.controller.outcome!.kind, RestoreOutcomeKind.busyCompressing);
      expect(s.transport.count('list'), 1);
      s = await failing(const RestoreBusy(CheckpointBusyReason.replying));
      expect(s.controller.outcome!.kind, RestoreOutcomeKind.busyReplying);
    });

    test('a stale session is re-established and never retried', () async {
      final s = await failing(
        const RestoreFailed(
          CheckpointFailureKind.sessionGone,
          filesPossiblyChanged: false,
        ),
      );
      expect(s.controller.outcome!.kind, RestoreOutcomeKind.sessionGone);
      expect(s.chat.reestablished, 1);
      expect(s.transport.count('restore'), 1);
    });

    test('a restore in flight survives the app leaving the chat: its result lands here', () async {
      final s = _Setup();
      await s.openWithChanges();
      s.transport.restoreGate = Completer<void>();
      s.transport.restore = const Restored(historyRemoved: 1);
      final pending = s.controller.confirmRestore(
        s.controller.beginRestore(_h1)!,
      );
      await Future<void>.delayed(Duration.zero);
      s.controller.panelClosed();
      s.transport.restoreGate!.complete();
      await pending;
      expect(s.controller.outcome!.kind, RestoreOutcomeKind.restored);
      expect(s.chat.refetches, 1);
    });
  });

  group('records carry fixed words only', () {
    test('no span, breadcrumb or log holds a path, hash, reason, message or server text', () async {
      final tracer = RecordingTracer();
      final trail = BreadcrumbTrail();
      final events = <(String, Map<String, Object>)>[];
      final telemetry = ActionTelemetry(
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          serverAttributes: {'hermes.version': 'test'},
          events: (name, [attributes = const {}]) =>
              events.add((name, Map.of(attributes))),
        ),
        breadcrumbs: Breadcrumbs.of(trail),
      );
      final s = _Setup(telemetry: telemetry);
      s.chat.quote = const PromptQuote(
        messageId: 'm-secret',
        text: 'my secret prompt',
      );
      const secretFile = ChangedFile(
        path: 'secrets/prod.env',
        restorable: true,
        changes: 3,
        diff: 'password=hunter2',
      );
      await s.openWithChanges(files: const [secretFile]);
      s.transport.restore = const RestoreFailed(
        CheckpointFailureKind.other,
        filesPossiblyChanged: true,
      );
      await s.controller.confirmRestore(
        s.controller.beginRestore(_h1, filePath: 'secrets/prod.env')!,
      );
      s.transport.list = const CheckpointsFailed(CheckpointFailureKind.other);
      await s.controller.refresh();
      await s.controller.refresh();

      final recorded = [
        for (final span in tracer.spans) ...[
          span.name,
          ...span.attributes.keys,
          ...span.attributes.values.map((v) => '$v'),
        ],
        for (final e in events) ...[
          e.$1,
          ...e.$2.keys,
          ...e.$2.values.map((v) => '$v'),
        ],
        ...trail.recent.map((b) => '$b'),
      ].join(' ');
      expect(
        trail.recent.map((b) => b.name),
        containsAll([
          'chat.checkpoints.opened',
          'chat.checkpoints.restore_confirmed',
        ]),
      );
      for (final secret in [
        'secrets',
        'prod.env',
        'hunter2',
        'my secret prompt',
        'm-secret',
        _h1,
        _h2,
        'a1a1',
        'stored-1',
        'work',
        'rt-1',
      ]) {
        expect(recorded, isNot(contains(secret)), reason: secret);
      }
      expect(
        tracer.spans.map((s) => s.name),
        containsAll([
          'chat.checkpoints.list',
          'chat.checkpoints.diff',
          'chat.checkpoints.restore',
        ]),
      );
      expect(tracer.spans.every((s) => s.ended), isTrue);
      // The failure streak is logged once, with a fixed kind.
      expect(
        events.where((e) => e.$1 == 'chat.checkpoints.read_failed'),
        hasLength(1),
      );
    });
  });
}
