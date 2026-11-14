import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/chat/activity/working_summary_source.dart';

void main() {
  final scope = Object();

  test('nothing working yields null', () {
    expect(WorkingSummarySource().read(scope, const WorkingInputs()), isNull);
  });

  test('the sentence that changed last is the newest', () {
    final source = WorkingSummarySource();
    var summary = source.read(
      scope,
      const WorkingInputs(waits: {'status': 'Waiting for background process'}),
    )!;
    expect(summary.sentence.text, 'Waiting for background process');
    summary = source.read(
      scope,
      const WorkingInputs(
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
        waits: {'status': 'Waiting for background process'},
        processes: 2,
      ),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.processes);
    // A new wait text is newer than the processes.
    summary = source.read(
      scope,
      const WorkingInputs(
        waits: {'status': 'Recalled 5 memories'},
        processes: 2,
      ),
    )!;
    expect(summary.sentence.text, 'Recalled 5 memories');
    // It clears: the next active source takes over.
    summary = source.read(scope, const WorkingInputs(processes: 2))!;
    expect(summary.sentence.kind, WorkingSentenceKind.processes);
  });

  test('a goal tick that repeats its text does not steal newest', () {
    final source = WorkingSummarySource();
    const goal = 'Ship the weekly digest';
    source.read(scope, const WorkingInputs(goal: goal));
    source.read(
      scope,
      const WorkingInputs(goal: goal, waits: {'status': 'Recalled 2 memories'}),
    );
    for (var tick = 0; tick < 3; tick++) {
      final summary = source.read(
        scope,
        const WorkingInputs(
          goal: goal,
          waits: {'status': 'Recalled 2 memories'},
        ),
      )!;
      expect(summary.sentence.text, 'Recalled 2 memories');
    }
  });

  test('loop and heartbeat are their own sources', () {
    final source = WorkingSummarySource();
    source.read(scope, const WorkingInputs(loop: 'Check the build'));
    final summary = source.read(
      scope,
      const WorkingInputs(loop: 'Check the build', heartbeat: 'Ping'),
    )!;
    expect(summary.sentence.text, 'Ping');
    expect(
      source
          .read(scope, const WorkingInputs(loop: 'Check the build'))!
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
      const WorkingInputs(planOpen: true, planDone: 2, planTotal: 5),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.plan);
    expect(summary.counters.single.value, 2);
    expect(summary.counters.single.total, 5);
  });

  test('a plan of unsupported tasks has no counter', () {
    final summary = WorkingSummarySource().read(
      scope,
      const WorkingInputs(planOpen: true),
    )!;
    expect(summary.counters, isEmpty);
  });

  test('a finished plan, with nothing else, is not working', () {
    expect(
      WorkingSummarySource().read(
        scope,
        const WorkingInputs(planDone: 5, planTotal: 5),
      ),
      isNull,
    );
  });

  test('aggregating is combining answers, without a models count', () {
    final summary = WorkingSummarySource().read(
      scope,
      const WorkingInputs(moa: MoaInput(combining: true, models: 3)),
    )!;
    expect(summary.sentence.kind, WorkingSentenceKind.combiningAnswers);
    expect(summary.sentence.count, isNull);
  });

  test('chats keep their own stamps', () {
    final source = WorkingSummarySource();
    final other = Object();
    source.read(scope, const WorkingInputs(restoring: true));
    final summary = source.read(
      other,
      const WorkingInputs(waits: {'status': 'Hello'}),
    )!;
    expect(summary.sentence.text, 'Hello');
    expect(
      source.read(scope, const WorkingInputs(restoring: true))!.sentence.kind,
      WorkingSentenceKind.restoring,
    );
  });
}
