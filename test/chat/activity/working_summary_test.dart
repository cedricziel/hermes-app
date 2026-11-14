import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';

WorkingSentence _status(String text, int at) =>
    WorkingSentence(WorkingSentenceKind.status, at: at, text: text);

void main() {
  group('sentence', () {
    test('nothing working yields null', () {
      expect(WorkingSummary.compute(), isNull);
    });

    test('the newest sentence wins across sources', () {
      final summary = WorkingSummary.compute(
        sentences: [
          _status('Recalled 5 memories', 1),
          const WorkingSentence(WorkingSentenceKind.processes, at: 3, count: 2),
          const WorkingSentence(WorkingSentenceKind.restoring, at: 2),
        ],
      )!;
      expect(summary.sentence.kind, WorkingSentenceKind.processes);
      expect(summary.sentence.count, 2);
    });

    test('clearing the newest falls back to the next active one', () {
      final older = _status('Waiting for background process', 1);
      final both = [
        older,
        const WorkingSentence(
          WorkingSentenceKind.askingModels,
          at: 2,
          count: 3,
        ),
      ];
      expect(
        WorkingSummary.compute(sentences: both)!.sentence.kind,
        WorkingSentenceKind.askingModels,
      );
      final summary = WorkingSummary.compute(sentences: [older])!;
      expect(summary.sentence.kind, WorkingSentenceKind.status);
      expect(summary.sentence.text, 'Waiting for background process');
    });

    test('every source kind can be the sentence', () {
      for (final kind in WorkingSentenceKind.values) {
        if (kind == WorkingSentenceKind.plan) continue;
        final summary = WorkingSummary.compute(
          sentences: [WorkingSentence(kind, at: 1, text: 'Ship the digest')],
        )!;
        expect(summary.sentence.kind, kind);
      }
    });

    test('a blank server sentence is ignored', () {
      expect(
        WorkingSummary.compute(sentences: [_status('  ', 5), _status('', 6)]),
        isNull,
      );
      final summary = WorkingSummary.compute(
        sentences: [_status('Recalled 2 memories', 1), _status(' ', 2)],
      )!;
      expect(summary.sentence.text, 'Recalled 2 memories');
    });

    test('a plan with an open task and nothing else reads as the plan', () {
      final summary = WorkingSummary.compute(planOpen: true)!;
      expect(summary.sentence.kind, WorkingSentenceKind.plan);
      expect(summary.sentence.text, isNull);
    });

    test('a reported sentence beats the plan fallback', () {
      final summary = WorkingSummary.compute(
        planOpen: true,
        sentences: [_status('Recalled 5 memories', 1)],
      )!;
      expect(summary.sentence.kind, WorkingSentenceKind.status);
    });

    test('a plan with no open task is not work', () {
      expect(WorkingSummary.compute(), isNull);
      expect(
        WorkingSummary.compute(
          counters: [WorkingCounter.plan(done: 5, total: 5, at: 1)],
        ),
        isNull,
      );
    });
  });

  group('counters', () {
    test('only reported values are shown and unknown ones are left out', () {
      final summary = WorkingSummary.compute(
        planOpen: true,
        sentences: [_status('Recalled 5 memories', 1)],
        counters: [
          WorkingCounter.plan(done: null, total: 5, at: 1),
          WorkingCounter.references(done: 2, total: null, at: 2),
          WorkingCounter.processes(running: 0, at: 3),
        ],
      )!;
      expect(summary.counters, isEmpty);
    });

    test('the plan counter reports done and total while a task is open', () {
      final summary = WorkingSummary.compute(
        planOpen: true,
        counters: [WorkingCounter.plan(done: 2, total: 5, at: 1)],
      )!;
      expect(summary.counters, hasLength(1));
      final counter = summary.counters.single;
      expect(counter.kind, WorkingCounterKind.plan);
      expect((counter.value, counter.total), (2, 5));
    });

    test('the plan counter is dropped when every task is done', () {
      final summary = WorkingSummary.compute(
        sentences: [_status('Recalled 5 memories', 1)],
        counters: [WorkingCounter.plan(done: 5, total: 5, at: 2)],
      )!;
      expect(summary.counters, isEmpty);
    });

    test('at most two counters, the two that changed last', () {
      final summary = WorkingSummary.compute(
        planOpen: true,
        sentences: [_status('Asking 5 models', 1)],
        counters: [
          WorkingCounter.plan(done: 2, total: 5, at: 1),
          WorkingCounter.processes(running: 1, at: 3),
          WorkingCounter.references(done: 3, total: 5, at: 2),
        ],
      )!;
      expect(summary.counters.map((c) => c.kind), [
        WorkingCounterKind.processes,
        WorkingCounterKind.references,
      ]);
    });

    test('a repeated kind keeps the newest value', () {
      final summary = WorkingSummary.compute(
        sentences: [_status('Working', 1)],
        counters: [
          WorkingCounter.processes(running: 1, at: 1),
          WorkingCounter.processes(running: 2, at: 4),
        ],
      )!;
      expect(summary.counters.single.value, 2);
    });

    test('a counter alone is not work', () {
      expect(
        WorkingSummary.compute(
          counters: [WorkingCounter.processes(running: 2, at: 1)],
        ),
        isNull,
      );
    });
  });
}
