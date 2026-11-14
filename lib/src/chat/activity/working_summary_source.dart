import '../chat_controller.dart';
import '../chat_models.dart';
import '../todo_plan/todo_plan_state.dart';
import 'working_summary.dart';

/// What the open chat's Working sources report right now, as plain values.
/// [WorkingSummarySource] turns it into a [WorkingSummary] and keeps the
/// arrival order between reads.
class WorkingInputs {
  const WorkingInputs({
    this.waits = const {},
    this.goal,
    this.loop,
    this.heartbeat,
    this.processes = 0,
    this.moa,
    this.restoring = false,
    this.planOpen = false,
    this.planDone,
    this.planTotal,
  });

  /// Server text of each `status.update` kind that is not empty, memory
  /// recalls included.
  final Map<String, String> waits;

  /// The goal's title, the loop's and the heartbeat's prompt while each is
  /// active; null when it is not.
  final String? goal, loop, heartbeat;

  /// Process output cards that are not closed.
  final int processes;

  /// The newest live mixture-of-agents card.
  final MoaInput? moa;
  final bool restoring;

  /// A plan task is neither done nor cancelled.
  final bool planOpen;

  /// Done and all tasks of the plan; null when a task is of an unsupported
  /// shape.
  final int? planDone, planTotal;
}

class MoaInput {
  const MoaInput({required this.combining, this.models, this.done, this.total});

  /// The phase is "Aggregating".
  final bool combining;

  /// How many models are asked, when reported.
  final int? models, done, total;
}

/// Reads the Working sources of a chat and stamps them in arrival order.
///
/// One source object belongs to one controller, so every stamp comes from one
/// monotonic sequence and sources order against each other. A source takes the
/// next number only when its value really changes (a tick that repeats the
/// same goal text does not) and keeps it until the value changes again or the
/// source clears. Stamps are kept per chat.
class WorkingSummarySource {
  int _sequence = 0;
  final _stamps = Expando<Map<String, (Object, int)>>('working stamps');

  /// The summary of [scope] (the chat's thread) for [inputs]; null when
  /// nothing is working.
  WorkingSummary? read(Object scope, WorkingInputs inputs) {
    final stamps = _stamps[scope] ??= {};
    final seen = <String>{};
    int? at(String key, Object value) {
      seen.add(key);
      final old = stamps[key];
      if (old != null && old.$1 == value) return old.$2;
      return (stamps[key] = (value, ++_sequence)).$2;
    }

    final sentences = <WorkingSentence>[];
    void sentence(
      String key,
      WorkingSentenceKind kind, {
      String? text,
      int? count,
    }) {
      final stamp = at(key, (kind, text, count));
      sentences.add(
        WorkingSentence(kind, at: stamp!, text: text, count: count),
      );
    }

    for (final MapEntry(:key, :value) in inputs.waits.entries) {
      if (value.trim().isEmpty) continue;
      sentence('wait:$key', WorkingSentenceKind.status, text: value);
    }
    for (final (key, text) in [
      ('goal', inputs.goal),
      ('loop', inputs.loop),
      ('heartbeat', inputs.heartbeat),
    ]) {
      if (text != null && text.trim().isNotEmpty) {
        sentence(key, WorkingSentenceKind.goal, text: text);
      }
    }
    if (inputs.processes > 0) {
      sentence(
        'processes',
        WorkingSentenceKind.processes,
        count: inputs.processes,
      );
    }
    final moa = inputs.moa;
    if (moa != null) {
      sentence(
        'moa',
        moa.combining
            ? WorkingSentenceKind.combiningAnswers
            : WorkingSentenceKind.askingModels,
        count: moa.combining ? null : moa.models,
      );
    }
    if (inputs.restoring) sentence('restoring', WorkingSentenceKind.restoring);

    final counters = <WorkingCounter>[];
    final planDone = inputs.planDone, planTotal = inputs.planTotal;
    if (inputs.planOpen && planDone != null && planTotal != null) {
      counters.add(
        WorkingCounter.plan(
          done: planDone,
          total: planTotal,
          at: at('plan', (planDone, planTotal))!,
        ),
      );
    }
    if (inputs.processes > 0) {
      counters.add(
        WorkingCounter.processes(
          running: inputs.processes,
          at: at('processes#', inputs.processes)!,
        ),
      );
    }
    if (moa != null && moa.done != null && moa.total != null) {
      counters.add(
        WorkingCounter.references(
          done: moa.done,
          total: moa.total,
          at: at('references', (moa.done, moa.total))!,
        ),
      );
    }
    stamps.removeWhere((key, _) => !seen.contains(key));
    return WorkingSummary.compute(
      sentences: sentences,
      planOpen: inputs.planOpen,
      counters: counters,
    );
  }
}

/// The Working sources of [thread] in [chat].
WorkingInputs workingInputsOf(ChatController chat, ChatThread thread) {
  final state = chat.sessionStateIn(thread);
  String? active(Map<String, Object?>? section, String key) =>
      section != null && section['status'] == 'active'
      ? switch (section[key]) {
          final String text => text,
          _ => null,
        }
      : null;
  final control = state?.control;
  final live = chat.moaIn(thread).where((progress) => progress.live).lastOrNull;
  final snapshot = chat.todoPlanIn(thread)?.snapshot;
  final open =
      snapshot?.entries.any(
        (entry) =>
            entry != null &&
            entry.status != TodoStatus.completed &&
            entry.status != TodoStatus.cancelled,
      ) ??
      false;
  return WorkingInputs(
    waits: {...?state?.waits, ...?state?.recallWaits},
    goal: active(control?.goal, 'title'),
    loop: active(control?.loop, 'prompt'),
    heartbeat: active(control?.heartbeat, 'prompt'),
    processes:
        chat.processOutputsIn(thread)?.cards.where((c) => !c.closed).length ??
        0,
    moa: live == null
        ? null
        : MoaInput(
            combining: live.phase == 'Aggregating',
            models: live.total,
            done: live.done,
            total: live.total,
          ),
    restoring: state?.resume?.status == 'loading',
    planOpen: open,
    planDone: snapshot?.completedCount,
    planTotal: snapshot?.entries.length,
  );
}
