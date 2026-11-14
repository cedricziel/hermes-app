import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/chat/activity/working_summary_source.dart';

void main() {
  turnScoped();
  final scope = Object();

  test('nothing working yields null', () {
    expect(
      WorkingSummarySource().read(scope, const WorkingInputs(replying: true)),
      isNull,
    );
  });

  test('the sentence that changed last is the newest', () {
    final source = WorkingSummarySource();
    var summary = source.read(
      scope,
      const WorkingInputs(
        replying: true,
        waits: {'status': 'Waiting for background process'},
      ),
    )!;
    expect(summary.sentence.text, 'Waiting for background process');
    summary = source.read(
      scope,
      const WorkingInputs(
        replying: true,
        waits: {'status': 'Waiting for background process'},
        processes: 2,
      ),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.processes);
    expect(summary.sentence.count, 2);
    // The wait repeats unchanged: it keeps its older stamp.
    summary = source.read(
      scope,
      const WorkingInputs(
        replying: true,
        waits: {'status': 'Waiting for background process'},
        processes: 2,
      ),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.processes);
    // A new wait text is newer than the processes.
    summary = source.read(
      scope,
      const WorkingInputs(
        replying: true,
        waits: {'status': 'Recalled 5 memories'},
        processes: 2,
      ),
    )!;
    expect(summary.sentence.text, 'Recalled 5 memories');
    // It clears: the next active source takes over.
    summary = source.read(
      scope,
      const WorkingInputs(replying: true, processes: 2),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.processes);
  });

  test('a goal tick that repeats its text does not steal newest', () {
    final source = WorkingSummarySource();
    const goal = 'Ship the weekly digest';
    source.read(scope, const WorkingInputs(replying: true, goal: goal));
    source.read(
      scope,
      const WorkingInputs(
        replying: true,
        goal: goal,
        waits: {'status': 'Recalled 2 memories'},
      ),
    );
    for (var tick = 0; tick < 3; tick++) {
      final summary = source.read(
        scope,
        const WorkingInputs(
          replying: true,
          goal: goal,
          waits: {'status': 'Recalled 2 memories'},
        ),
      )!;
      expect(summary.sentence.text, 'Recalled 2 memories');
    }
  });

  test('loop and heartbeat are their own sources', () {
    final source = WorkingSummarySource();
    source.read(
      scope,
      const WorkingInputs(replying: true, loop: 'Check the build'),
    );
    final summary = source.read(
      scope,
      const WorkingInputs(
        replying: true,
        loop: 'Check the build',
        heartbeat: 'Ping',
      ),
    )!;
    expect(summary.sentence.text, 'Ping');
    expect(
      source
          .read(
            scope,
            const WorkingInputs(replying: true, loop: 'Check the build'),
          )!
          .sentence
          .text,
      'Check the build',
    );
  });

  test('stamps are one sequence: a later counter change orders against '
      'sentences', () {
    final source = WorkingSummarySource();
    source.read(
      scope,
      const WorkingInputs(
        replying: true,
        planOpen: true,
        planDone: 1,
        planTotal: 5,
        processes: 1,
        moa: MoaInput(combining: false, models: 3, done: 0, total: 3),
      ),
    );
    final summary = source.read(
      scope,
      const WorkingInputs(
        replying: true,
        planOpen: true,
        planDone: 2,
        planTotal: 5,
        processes: 1,
        moa: MoaInput(combining: false, models: 3, done: 0, total: 3),
      ),
    )!;
    // The plan counter changed last. The references counter repeats the
    // asking sentence, so the processes counter is the second one.
    expect(summary.sentence.kind, WorkingSentenceKind.askingModels);
    expect(summary.counters.map((c) => c.kind), [
      WorkingCounterKind.plan,
      WorkingCounterKind.processes,
    ]);
  });

  test('a plan with an open task and nothing else reads as the plan', () {
    final summary = WorkingSummarySource().read(
      scope,
      const WorkingInputs(
        replying: true,
        planOpen: true,
        planDone: 2,
        planTotal: 5,
      ),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.plan);
    expect(summary.counters.single.value, 2);
    expect(summary.counters.single.total, 5);
  });

  test('a plan of unsupported tasks has no counter', () {
    final summary = WorkingSummarySource().read(
      scope,
      const WorkingInputs(replying: true, planOpen: true),
    )!;
    expect(summary.counters, isEmpty);
  });

  test('a finished plan, with nothing else, is not working', () {
    expect(
      WorkingSummarySource().read(
        scope,
        const WorkingInputs(replying: true, planDone: 5, planTotal: 5),
      ),
      isNull,
    );
  });

  test('aggregating is combining answers, without a models count', () {
    final summary = WorkingSummarySource().read(
      scope,
      const WorkingInputs(
        replying: true,
        moa: MoaInput(combining: true, models: 3),
      ),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.combiningAnswers);
    expect(summary.sentence.count, isNull);
  });

  test('chats keep their own stamps', () {
    final source = WorkingSummarySource();
    final other = Object();
    source.read(scope, const WorkingInputs(replying: true, restoring: true));
    final summary = source.read(
      other,
      const WorkingInputs(replying: true, waits: {'status': 'Hello'}),
    )!;
    expect(summary.sentence.text, 'Hello');
    expect(
      source
          .read(scope, const WorkingInputs(replying: true, restoring: true))!
          .sentence
          .kind,
      WorkingSentenceKind.restoring,
    );
  });
}

void turnScoped() {
  final scope = Object();

  test('status, goal, heartbeat and plan count only while a turn runs', () {
    final source = WorkingSummarySource();
    const inputs = WorkingInputs(
      waits: {'status': 'Recalled 5 memories'},
      goal: 'Ship the digest',
      heartbeat: 'Ping',
      planOpen: true,
      planDone: 1,
      planTotal: 3,
    );
    expect(source.read(scope, inputs), isNull);
    expect(
      source.read(scope, const WorkingInputs(replying: true)),
      isNull,
      reason: 'a turn alone is not a sentence',
    );
  });

  test('a process counts only while a turn runs; mixture-of-agents and '
      'restoring outlive it', () {
    final source = WorkingSummarySource();
    // The backend reports no process exit, so an open card does not keep the
    // line up after the turn.
    expect(source.read(scope, const WorkingInputs(processes: 1)), isNull);
    expect(
      source
          .read(scope, const WorkingInputs(replying: true, processes: 1))!
          .sentence
          .kind,
      WorkingSentenceKind.processes,
    );
    expect(
      source.read(
        scope,
        const WorkingInputs(moa: MoaInput(combining: false, models: 2)),
      ),
      isNotNull,
    );
    expect(source.read(scope, const WorkingInputs(restoring: true)), isNotNull);
  });

  test('a wait counts when it arrived after the previous turn ended, also '
      'ahead of a server-started turn; an earlier one does not', () {
    final source = WorkingSummarySource();
    const waits = {'process': 'Resuming interrupted turn…'};
    final before = source.next();
    source.turnEnded(scope);
    final ahead = source.next();
    // The status came first, then the turn starts.
    expect(
      source.read(
        scope,
        WorkingInputs(waits: waits, waitAt: {'process': ahead}),
      ),
      isNull,
    );
    final summary = source.read(
      scope,
      WorkingInputs(replying: true, waits: waits, waitAt: {'process': ahead}),
    );
    expect(summary!.sentence.text, 'Resuming interrupted turn…');
    expect(
      source.read(
        scope,
        WorkingInputs(
          replying: true,
          waits: waits,
          waitAt: {'process': before},
        ),
      ),
      isNull,
    );
  });

  test('a queued turn that follows at once does not inherit the last '
      'turn\'s waits', () {
    final source = WorkingSummarySource();
    source.read(scope, const WorkingInputs(replying: true));
    final first = source.next();
    source.turnEnded(scope);
    // The next turn is already running when anything reads.
    final summary = source.read(
      scope,
      WorkingInputs(
        replying: true,
        waits: const {'status': 'Recalled 5 memories'},
        waitAt: {'status': first},
      ),
    );
    expect(summary, isNull);
  });

  test('arrival stamps decide newest, not the order of reads', () {
    final source = WorkingSummarySource();
    source.read(scope, const WorkingInputs(replying: true));
    final recall = source.next();
    final status = source.next();
    final summary = source.read(
      scope,
      WorkingInputs(
        replying: true,
        waits: const {'lifecycle': 'Recalled 2 notes', 'status': 'Thinking'},
        waitAt: {'lifecycle': recall, 'status': status},
      ),
    );
    expect(summary!.sentence.text, 'Thinking');
  });
}
