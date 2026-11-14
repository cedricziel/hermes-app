import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/checkpoints/action_telemetry.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/context/context_controller.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/session_usage/usage_snapshot.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_checkpoints_transport.dart';
import '../../support/recording_tracer.dart';

UsageSnapshot _usage(
  int percent, {
  int max = 200000,
  int? used,
  bool estimated = false,
  ContextSource? source = ContextSource.providerUsage,
}) => UsageSnapshot(
  contextUsed: used ?? max * percent ~/ 100,
  contextMax: max,
  contextPercent: percent,
  contextEstimated: estimated,
  contextSource: source,
);

class _Setup {
  _Setup({ActionTelemetry? telemetry, bool live = true}) {
    controller = ContextController(
      transport: transport,
      bridge: chat.bridge,
      telemetry: telemetry ?? const ActionTelemetry(),
    )..bind(fakeScope(live: live));
    addTearDown(controller.dispose);
  }
  final transport = FakeCheckpointsTransport();
  final chat = FakeChatBridge();
  late final ContextController controller;
}

void main() {
  group('the row', () {
    test('needs all three figures; nothing says unsupported without them', () {
      final s = _Setup();
      expect(s.controller.hasRow, isFalse);
      s.controller.updateUsage(const UsageSnapshot(contextPercent: 62));
      expect(s.controller.hasRow, isFalse);
      s.controller.updateUsage(_usage(62, estimated: true));
      expect(s.controller.hasRow, isTrue);
      expect(s.controller.figures!.estimated, isTrue);
      s.controller.updateUsage(null);
      expect(s.controller.hasRow, isFalse);
    });

    test('levels: neutral, nearly full at 80, critical at 95, full at 100 or over the window', () {
      final s = _Setup();
      ContextLevel at(UsageSnapshot usage) {
        s.controller.updateUsage(usage);
        return s.controller.level;
      }

      expect(at(_usage(79)), ContextLevel.normal);
      expect(at(_usage(80)), ContextLevel.nearlyFull);
      expect(at(_usage(94)), ContextLevel.nearlyFull);
      expect(at(_usage(95)), ContextLevel.critical);
      expect(at(_usage(100)), ContextLevel.full);
      expect(at(_usage(100, used: 212000)), ContextLevel.full);
      expect(s.controller.figures!.used, 212000);
    });

    test('disconnect keeps the last values, marked not up to date, and turns compress off', () {
      final s = _Setup()..controller.updateUsage(_usage(62));
      s.controller.disconnected();
      expect(s.controller.hasRow, isTrue);
      expect(s.controller.notUpToDate, isTrue);
      expect(s.controller.canCompress, isFalse);
      expect(s.controller.compressRefusal, CompressRefusal.disconnected);
    });

    test('a stored chat without a session has no compress', () {
      final s = _Setup(live: false)..controller.updateUsage(_usage(62));
      expect(s.controller.compressRefusal, CompressRefusal.unavailable);
      expect(s.controller.beginCompress(), isNull);
    });
  });

  group('the breakdown', () {
    test(
      'one read per trigger: open, turn end while open, compaction while open',
      () async {
        final s = _Setup();
        s.transport.breakdown = const Breakdown(
          categories: [ContextCategory(ContextCategoryKind.rules, 5)],
        );
        await s.controller.turnEnded();
        await s.controller.compacted();
        expect(s.transport.count('breakdown'), 0, reason: 'details closed');
        await s.controller.openDetails();
        expect(s.transport.count('breakdown'), 1);
        expect(s.controller.breakdown!.categories, hasLength(1));
        await s.controller.turnEnded();
        expect(s.transport.count('breakdown'), 2);
        await s.controller.compacted();
        expect(s.transport.count('breakdown'), 3);
        expect(s.chat.usageReads, 2, reason: 'a compaction re-reads usage');
        s.controller.closeDetails();
        await s.controller.turnEnded();
        expect(s.transport.count('breakdown'), 3);
        expect(s.controller.breakdown, isNull);
      },
    );

    test('a late answer after a scope change is dropped', () async {
      final s = _Setup();
      s.transport
        ..breakdown = const Breakdown(
          categories: [ContextCategory(ContextCategoryKind.rules, 5)],
        )
        ..breakdownGate = Completer<void>();
      final pending = s.controller.openDetails();
      await Future<void>.delayed(Duration.zero);
      expect(s.controller.breakdownLoading, isTrue);
      s.controller.bind(fakeScope(thread: 'stored-2'));
      s.transport.breakdownGate!.complete();
      await pending;
      expect(s.controller.breakdown, isNull);
      expect(s.controller.breakdownLoading, isFalse);
    });

    test('unsupported hides the list with no error; failure keeps the row and reports once', () async {
      final s = _Setup()..controller.updateUsage(_usage(62));
      s.transport.breakdown = const BreakdownUnsupported();
      await s.controller.openDetails();
      expect(s.controller.breakdownSupported, isFalse);
      expect(s.controller.breakdownFailed, isFalse);
      expect(s.controller.hasRow, isTrue);

      final failed = _Setup()..controller.updateUsage(_usage(62));
      failed.transport.breakdown = const BreakdownFailed(
        CheckpointFailureKind.other,
      );
      await failed.controller.openDetails();
      expect(failed.controller.breakdownFailed, isTrue);
      expect(failed.controller.breakdown, isNull);
      expect(failed.controller.hasRow, isTrue);
      failed.transport.breakdown = const Breakdown(categories: []);
      await failed.controller.openDetails();
      expect(failed.controller.breakdownFailed, isFalse);
    });

    test(
      'App Lock drops the breakdown, closes the details and refuses compress',
      () async {
        final s = _Setup()..controller.updateUsage(_usage(62));
        s.transport.breakdown = const Breakdown(
          categories: [ContextCategory(ContextCategoryKind.rules, 5)],
        );
        await s.controller.openDetails();
        s.controller.setLocked(true);
        expect(s.controller.breakdown, isNull);
        expect(s.controller.detailsOpen, isFalse);
        expect(s.controller.canCompress, isFalse);
        expect(s.controller.suggestionVisible, isFalse);
        await s.controller.openDetails();
        expect(s.transport.count('breakdown'), 1);
        expect(
          s.controller.figures!.percent,
          62,
          reason: 'only the percentage may be drawn',
        );
      },
    );

    test('sign-out discards everything', () async {
      final s = _Setup()..controller.updateUsage(_usage(62));
      await s.controller.openDetails();
      s.controller.clear();
      expect(s.controller.hasRow, isFalse);
      expect(s.controller.breakdown, isNull);
    });

    test('unknown values stay unknown, never zero', () async {
      final s = _Setup();
      s.transport.breakdown = const Breakdown(categories: []);
      await s.controller.openDetails();
      final b = s.controller.breakdown!;
      expect(
        (b.used, b.max, b.percent, b.estimated, b.model),
        (null, null, null, null, null),
      );
      expect(s.controller.hasRow, isFalse);
    });
  });

  group('the suggestion', () {
    test('shows at 85 or more while idle, once', () {
      final s = _Setup();
      s.controller.updateUsage(_usage(84));
      expect(s.controller.suggestionVisible, isFalse);
      s.controller.updateUsage(_usage(86));
      expect(s.controller.suggestionVisible, isTrue);
    });

    test('waits for an idle chat', () {
      final s = _Setup()..controller.updateUsage(_usage(90));
      s.chat.replying = true;
      expect(s.controller.suggestionVisible, isFalse);
      s.chat.replying = false;
      expect(s.controller.suggestionVisible, isTrue);
    });

    test('a local estimate does not earn a prompt below 95', () {
      final s = _Setup();
      s.controller.updateUsage(
        _usage(88, estimated: true, source: ContextSource.localEstimate),
      );
      expect(s.controller.suggestionVisible, isFalse);
      s.controller.updateUsage(
        _usage(96, estimated: true, source: ContextSource.localEstimate),
      );
      expect(s.controller.suggestionVisible, isTrue);
    });

    test(
      'Not now keeps it away until the context fell below 60 and filled again',
      () {
        final s = _Setup()..controller.updateUsage(_usage(90));
        s.controller.dismissSuggestion();
        s.controller.updateUsage(_usage(93));
        expect(s.controller.suggestionVisible, isFalse);
        s.controller.updateUsage(_usage(60));
        s.controller.updateUsage(_usage(88));
        expect(
          s.controller.suggestionVisible,
          isFalse,
          reason: 'it did not fall below 60',
        );
        s.controller.updateUsage(_usage(59));
        s.controller.updateUsage(_usage(88));
        expect(s.controller.suggestionVisible, isTrue);
      },
    );

    test('state is per controller (per thread) and cleared by sign-out', () {
      final a = _Setup()..controller.updateUsage(_usage(90));
      final b = _Setup()..controller.updateUsage(_usage(90));
      a.controller.dismissSuggestion();
      expect(b.controller.suggestionVisible, isTrue);
      b.controller.dismissSuggestion();
      b.controller.clear();
      b.controller.bind(fakeScope());
      b.controller.updateUsage(_usage(90));
      expect(b.controller.suggestionVisible, isTrue);
    });

    test('it does not return while a compress runs, and a compress counts as dismissal', () async {
      final s = _Setup()..controller.updateUsage(_usage(90));
      s.transport.compressGate = Completer<void>();
      final pending = s.controller.confirmCompress(
        s.controller.beginCompress()!,
      );
      await Future<void>.delayed(Duration.zero);
      expect(s.controller.suggestionVisible, isFalse);
      s.transport.compressGate!.complete();
      await pending;
      s.controller.updateUsage(_usage(91));
      expect(s.controller.suggestionVisible, isFalse);
    });
  });

  group(
    'compress is sent only after confirmation, for the chat it started in',
    () {
      test(
        'starting sends nothing; confirming sends once with the chat and focus',
        () async {
          final s = _Setup()..controller.updateUsage(_usage(90));
          final intent = s.controller.beginCompress()!;
          expect(s.transport.count('compress'), 0);
          await s.controller.confirmCompress(intent, focus: '  the schema ');
          await s.controller.confirmCompress(intent, focus: 'the schema');
          expect(s.transport.compressRequests, [
            (thread: 'stored-1', profile: 'work', focus: 'the schema'),
          ]);
        },
      );

      test(
        'a compress started in one chat is not sent after the controller moved',
        () async {
          final s = _Setup();
          final intent = s.controller.beginCompress()!;
          s.controller.bind(fakeScope(thread: 'stored-2'));
          await s.controller.confirmCompress(intent);
          expect(s.transport.count('compress'), 0);
        },
      );

      test('a reply that starts while the confirmation is open stops it and sends nothing', () async {
        final s = _Setup();
        final intent = s.controller.beginCompress()!;
        s.chat.replying = true;
        await s.controller.confirmCompress(intent);
        expect(s.transport.count('compress'), 0);
        expect(s.controller.outcome!.kind, CompressOutcomeKind.busyReplying);
      });

      test('not offered while replying or compressing', () async {
        final s = _Setup();
        s.chat.replying = true;
        expect(s.controller.compressRefusal, CompressRefusal.replying);
        expect(s.controller.beginCompress(), isNull);
        s.chat.replying = false;
        s.transport.compressGate = Completer<void>();
        final pending = s.controller.confirmCompress(
          s.controller.beginCompress()!,
        );
        await Future<void>.delayed(Duration.zero);
        expect(s.controller.compressing, isTrue);
        expect(s.controller.compressRefusal, CompressRefusal.compressing);
        s.transport.compressGate!.complete();
        await pending;
        expect(s.controller.compressing, isFalse);
      });

      test('a focus the server would read as a command is refused and nothing is sent', () async {
        final s = _Setup();
        for (final focus in [
          '--preview the schema',
          'Here 3',
          'up to here',
          'the schema -k',
        ]) {
          expect(s.controller.focusAcceptable(focus), isFalse, reason: focus);
          await s.controller.confirmCompress(
            s.controller.beginCompress()!,
            focus: focus,
          );
        }
        expect(s.transport.count('compress'), 0);
        expect(s.controller.focusAcceptable('the database schema'), isTrue);
      });

      test('no transport means unavailable', () {
        final c = ContextController(
          transport: null,
          bridge: FakeChatBridge().bridge,
        )..bind(fakeScope());
        addTearDown(c.dispose);
        expect(c.beginCompress(), isNull);
      });
    },
  );

  group('every compress outcome', () {
    Future<_Setup> run(CompressionResult result) async {
      final s = _Setup()..controller.updateUsage(_usage(90));
      s.transport.compress = result;
      await s.controller.confirmCompress(s.controller.beginCompress()!);
      return s;
    }

    test('compressed re-reads the chat and usage and carries counts', () async {
      final s = await run(
        const Compressed(
          beforeMessages: 42,
          afterMessages: 9,
          beforeTokens: 120000,
          afterTokens: 30000,
          fallbackUsed: true,
        ),
      );
      final o = s.controller.outcome!;
      expect(o.kind, CompressOutcomeKind.compressed);
      expect(
        (
          o.beforeMessages,
          o.afterMessages,
          o.beforeTokens,
          o.afterTokens,
          o.fallbackUsed,
        ),
        (42, 9, 120000, 30000, true),
      );
      expect(s.chat.refetches, 1);
      expect(s.chat.usageReads, 1);
    });

    test(
      'it reads the breakdown again after a compress when the details are open',
      () async {
        final s = _Setup();
        await s.controller.openDetails();
        await s.controller.confirmCompress(s.controller.beginCompress()!);
        expect(s.transport.count('breakdown'), 2);
      },
    );

    test(
      'nothing to compress, would not shrink and aborted change nothing',
      () async {
        for (final (result, kind) in <(CompressionResult, CompressOutcomeKind)>[
          (const NothingToCompress(), CompressOutcomeKind.nothingToCompress),
          (const WouldNotShrink(), CompressOutcomeKind.wouldNotShrink),
          (const CompressionAborted(), CompressOutcomeKind.aborted),
          (
            const CompressFailed(CheckpointFailureKind.other),
            CompressOutcomeKind.failed,
          ),
        ]) {
          final s = await run(result);
          expect(s.controller.outcome!.kind, kind);
          expect(s.chat.refetches, 0);
          expect(
            s.controller.canCompress,
            isTrue,
            reason: 'offered again behind a new confirmation',
          );
        }
      },
    );

    test('4009 splits a running compress from a running reply', () async {
      var s = await run(const CompressBusy(CheckpointBusyReason.compressing));
      expect(s.controller.outcome!.kind, CompressOutcomeKind.busyCompressing);
      s = await run(const CompressBusy(CheckpointBusyReason.replying));
      expect(s.controller.outcome!.kind, CompressOutcomeKind.busyReplying);
      expect(s.chat.refetches, 0);
    });

    test('another compression holds the lock: usage is re-read', () async {
      final s = await run(const CompressLockHeld());
      expect(s.controller.outcome!.kind, CompressOutcomeKind.lockHeld);
      expect(s.chat.usageReads, 1);
      expect(s.chat.refetches, 0);
    });

    test('a lost answer is "couldn\'t confirm", re-reads, never resends and is offered again', () async {
      final s = await run(const CompressMayHaveHappened());
      expect(s.controller.outcome!.kind, CompressOutcomeKind.couldntConfirm);
      expect(s.controller.outcome!.kind, isNot(CompressOutcomeKind.compressed));
      expect(s.transport.count('compress'), 1);
      expect(s.chat.refetches, 1);
      expect(s.chat.usageReads, 1);
      final again = s.controller.beginCompress()!;
      expect(s.transport.count('compress'), 1);
      await s.controller.confirmCompress(again);
      expect(s.transport.count('compress'), 2);
    });

    test('a transport that throws is a lost answer', () async {
      final s = _Setup();
      s.transport.compressGate = null;
      final c = ContextController(transport: _Throwing(), bridge: s.chat.bridge)
        ..bind(fakeScope());
      addTearDown(c.dispose);
      await c.confirmCompress(c.beginCompress()!);
      expect(c.outcome!.kind, CompressOutcomeKind.couldntConfirm);
    });

    test(
      'a compute-host session re-reads the chat when it reports it settled',
      () async {
        final s = await run(const CompressPending());
        expect(s.controller.outcome!.kind, CompressOutcomeKind.pending);
        expect(s.controller.compressing, isTrue);
        expect(s.chat.refetches, 0);
        await s.controller.sessionSettled();
        expect(s.controller.compressing, isFalse);
        expect(s.chat.refetches, 1);
        await s.controller.sessionSettled();
        expect(s.chat.refetches, 1);
      },
    );

    test('an old server stops offering compress', () async {
      final s = await run(const CompressUnsupported());
      expect(s.controller.outcome!.kind, CompressOutcomeKind.unsupported);
      expect(s.controller.compressSupported, isFalse);
      expect(s.controller.beginCompress(), isNull);
    });

    test('a compress in flight survives the user leaving the chat: its outcome lands here', () async {
      final s = _Setup();
      s.transport
        ..compress = const Compressed(beforeMessages: 4, afterMessages: 2)
        ..compressGate = Completer<void>();
      final pending = s.controller.confirmCompress(
        s.controller.beginCompress()!,
      );
      await Future<void>.delayed(Duration.zero);
      s.controller.closeDetails();
      s.transport.compressGate!.complete();
      await pending;
      expect(s.controller.outcome!.kind, CompressOutcomeKind.compressed);
      expect(s.chat.refetches, 1);
    });
  });

  group('a compress that settles after the chat state changed', () {
    test('sign-out mid-compress keeps nothing and re-reads nothing', () async {
      final s = _Setup()..controller.updateUsage(_usage(90));
      s.transport
        ..compress = const Compressed(beforeMessages: 4, afterMessages: 2)
        ..compressGate = Completer<void>();
      final pending = s.controller.confirmCompress(
        s.controller.beginCompress()!,
      );
      await Future<void>.delayed(Duration.zero);
      s.controller.clear();
      s.transport.compressGate!.complete();
      await pending;
      expect(s.controller.outcome, isNull);
      expect(s.controller.compressing, isFalse);
      expect(s.chat.refetches, 0);
      expect(s.chat.usageReads, 0);
    });

    test('a pending compress does not stay "compressing" after sign-out or a rebind', () async {
      final s = _Setup();
      s.transport.compress = const CompressPending();
      await s.controller.confirmCompress(s.controller.beginCompress()!);
      expect(s.controller.compressing, isTrue);
      s.controller.bind(fakeScope(thread: 'stored-2'));
      expect(s.controller.compressing, isFalse);

      final t = _Setup();
      t.transport.compress = const CompressPending();
      await t.controller.confirmCompress(t.controller.beginCompress()!);
      t.controller.clear();
      expect(t.controller.compressing, isFalse);
      await t.controller.sessionSettled();
      expect(t.chat.refetches, 0);
    });
  });

  group('records carry fixed words only', () {
    test('a failing compress with a focus records the outcome and whether a focus was set, nothing else', () async {
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
      final s = _Setup(telemetry: telemetry)
        ..controller.updateUsage(_usage(90));
      s.transport.compress = const CompressFailed(CheckpointFailureKind.other);
      s.transport.breakdown = const BreakdownFailed(
        CheckpointFailureKind.other,
      );
      await s.controller.openDetails(from: ContextOpenFrom.suggestion);
      await s.controller.confirmCompress(
        s.controller.beginCompress()!,
        focus: 'keep the hunter2 credentials',
      );
      await s.controller.openDetails();

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
        containsAll(['chat.context.opened', 'chat.context.compress_confirmed']),
      );
      for (final secret in [
        'hunter2',
        'credentials',
        'keep the',
        'stored-1',
        'work',
        'rt-1',
      ]) {
        expect(recorded, isNot(contains(secret)), reason: secret);
      }
      final compress = tracer.spans.singleWhere(
        (s) => s.name == 'chat.context.compress',
      );
      expect(compress.attributes['focused'], isTrue);
      expect(compress.attributes['outcome'], 'failed');
      expect(compress.ended, isTrue);
      expect(
        events.where((e) => e.$1 == 'chat.context.read_failed'),
        hasLength(1),
      );
    });
  });
}

class _Throwing extends FakeCheckpointsTransport {
  @override
  Future<CompressionResult> compressSession(
    String threadId, {
    String? profile,
    String? focus,
  }) => throw StateError('socket gone: /home/u/secret');
}
