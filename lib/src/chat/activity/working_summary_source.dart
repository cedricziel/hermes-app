import '../chat_controller.dart';
import '../chat_models.dart';
import '../todo_plan/todo_plan_state.dart';
import 'working_summary.dart';

/// What the open chat's Working sources report right now, as plain values.
/// [WorkingSummarySource] turns it into a [WorkingSummary] and keeps the
/// arrival order between reads.
class WorkingInputs {
  const WorkingInputs({
    this.replying = false,
    this.waits = const {},
    this.waitAt = const {},
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

  /// A turn is running (a reply is in flight). Status, goal, loop, heartbeat
  /// and plan sentences are turn-scoped: they count only while it is true.
  /// Processes, mixture-of-agents and a restoring chat keep their own
  /// lifetimes.
  final bool replying;

  /// Server text of each `status.update` kind that is not empty, memory
  /// recalls included.
  final Map<String, String> waits;

  /// When each of [waits] arrived, from [WorkingSummarySource.next]; a wait
  /// without one is stamped when its text first changes in a read.
  final Map<String, int> waitAt;

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
  final _scopes = Expando<_Scope>('working scopes');

  /// The next number of the controller-wide arrival sequence.
  int next() => ++_sequence;

  /// Whether a status of [scope] that arrived at [arrived] belongs to the
  /// turn running now (or to the one about to start): it came after the last
  /// turn ended and a turn runs. Without a stamp it counts.
  bool waitIsCurrent(Object scope, int? arrived, {required bool replying}) {
    final end = _scopes[scope]?.turnEnd ?? 0;
    return replying && (arrived == null || arrived >= end);
  }

  /// A turn of [scope] ended (its reply settled, was stopped, failed or was
  /// reclaimed). Called where the event is applied, not when a read happens,
  /// so what arrived before it never counts for the turn that follows, even
  /// when a queued turn follows at once.
  void turnEnded(Object scope) {
    final state = _scopes[scope] ??= _Scope();
    state.turnEnd = next();
    state.endedSinceStart = true;
    state.endings++;
  }

  /// Whether a status of [scope] stamped at [arrived] came after the last
  /// turn ended, so a repeat of its text keeps the stamp.
  bool stampIsInCurrentTurn(Object scope, int arrived) =>
      arrived > (_scopes[scope]?.turnEnd ?? 0);

  /// The summary of [scope] (the chat's thread) for [inputs]; null when
  /// nothing is working.
  WorkingSummary? read(Object scope, WorkingInputs inputs) {
    final state = _scopes[scope] ??= _Scope();
    // A read after turnEnded() with a reply still running is a queued turn
    // that followed at once: it is a new turn whose end is not acknowledged.
    if (inputs.replying &&
        (!state.replying || state.endings != state.readEndings)) {
      state.endedSinceStart = false;
    }
    state.readEndings = state.endings;
    if (!inputs.replying && state.replying && !state.endedSinceStart) {
      // A turn ended without anyone saying so: mark it now.
      state.turnEnd = next();
    }
    state.replying = inputs.replying;
    final turn = inputs.replying;
    final stamps = state.stamps;
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

    if (turn) {
      for (final MapEntry(:key, :value) in inputs.waits.entries) {
        if (value.trim().isEmpty) continue;
        final arrived = inputs.waitAt[key];
        // A wait from before the last turn ended stays in the panel, not on
        // the line. One that came ahead of a server-started turn counts.
        if (arrived != null && arrived < state.turnEnd) continue;
        if (arrived == null) {
          sentence('wait:$key', WorkingSentenceKind.status, text: value);
        } else {
          sentences.add(
            WorkingSentence(
              WorkingSentenceKind.status,
              at: arrived,
              text: value,
            ),
          );
        }
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
    }
    // The backend reports no process exit (terminal.close comes only from the
    // close_terminal tool), so a card with output counts as running only
    // while its turn does.
    final processes = turn ? inputs.processes : 0;
    if (processes > 0) {
      sentence('processes', WorkingSentenceKind.processes, count: processes);
    }
    // A card is left live when the turn ends abnormally, so it counts only
    // while the turn runs.
    final moa = turn ? inputs.moa : null;
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
    final planOpen = turn && inputs.planOpen;
    if (planOpen && planDone != null && planTotal != null) {
      counters.add(
        WorkingCounter.plan(
          done: planDone,
          total: planTotal,
          at: at('plan', (planDone, planTotal))!,
        ),
      );
    }
    if (processes > 0) {
      counters.add(
        WorkingCounter.processes(
          running: processes,
          at: at('processes#', processes)!,
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
      planOpen: planOpen,
      counters: counters,
    );
  }
}

class _Scope {
  final stamps = <String, (Object, int)>{};
  bool replying = false;
  bool endedSinceStart = true;

  /// How many times turnEnded() ran, and how many a read has seen.
  int endings = 0, readEndings = 0;

  /// When the last turn ended, in the arrival sequence.
  int turnEnd = 0;
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
  // Goal, loop and heartbeat notices change with every tick; their
  // sentences come from the control state instead.
  const notices = {'goal', 'loop', 'heartbeat'};
  return WorkingInputs(
    replying: thread.isReplying,
    waits: {
      for (final MapEntry(:key, :value) in {
        ...?state?.waits,
        ...?state?.recallWaits,
      }.entries)
        if (!notices.contains(key)) key: value,
    },
    waitAt: {...?state?.waitAt},
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
