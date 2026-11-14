/// Which Working source a [WorkingSentence] comes from. The widget layer turns
/// a kind and its values into words; the server's own text is carried as it
/// comes and never translated.
enum WorkingSentenceKind {
  /// A `status.update` wait, such as "Recalled 5 memories". Server text.
  status,

  /// The session goal, loop or heartbeat. Server text.
  goal,

  /// Background processes run; `count` is how many.
  processes,

  /// A mixture-of-agents turn collects answers; `count` is how many models,
  /// when known.
  askingModels,

  /// A mixture-of-agents turn combines the answers.
  combiningAnswers,

  /// The chat is being restored.
  restoring,

  /// A plan has an open task and nothing else reports a sentence.
  plan,
}

/// One thing Hermes is doing now, as a typed sentence.
///
/// [at] orders arrival across sources: a larger value is newer. All stamps
/// come from one controller-wide sequence, and a source keeps its stamp until
/// its value changes or it clears. Only sources that are active now are passed
/// in, so clearing a source is leaving it out.
class WorkingSentence {
  const WorkingSentence(this.kind, {required this.at, this.text, this.count});

  final WorkingSentenceKind kind;
  final int at;

  /// Server text of a [WorkingSentenceKind.status] or
  /// [WorkingSentenceKind.goal] sentence.
  final String? text;

  /// How many processes or models, where the kind has one.
  final int? count;

  bool get _reportable => switch (kind) {
    WorkingSentenceKind.status ||
    WorkingSentenceKind.goal => text?.trim().isNotEmpty ?? false,
    _ => true,
  };
}

enum WorkingCounterKind { plan, processes, references }

/// A number the line shows beside the sentence. Built through the factories,
/// which keep only values the server reported; an unknown or empty value is
/// not a counter and [WorkingSummary.compute] never shows it.
class WorkingCounter {
  const WorkingCounter._(this.kind, this.value, this.total, this.at);

  /// Plan tasks done out of all tasks. Null when either is not known.
  factory WorkingCounter.plan({int? done, int? total, required int at}) =>
      WorkingCounter._(WorkingCounterKind.plan, done, total, at);

  /// Background processes running now.
  factory WorkingCounter.processes({required int running, required int at}) =>
      WorkingCounter._(WorkingCounterKind.processes, running, null, at);

  /// Mixture-of-agents references done out of all asked.
  factory WorkingCounter.references({int? done, int? total, required int at}) =>
      WorkingCounter._(WorkingCounterKind.references, done, total, at);

  final WorkingCounterKind kind;

  /// Done tasks, running processes or answered models.
  final int? value;

  /// All tasks or all models; null for processes.
  final int? total;

  /// When the value last changed, in the same order as [WorkingSentence.at].
  final int at;

  bool get _known {
    final value = this.value, total = this.total;
    return switch (kind) {
      WorkingCounterKind.processes => value != null && value > 0,
      WorkingCounterKind.plan || WorkingCounterKind.references =>
        value != null && total != null && total > 0 && value <= total,
    };
  }
}

/// Whether a counter of [kind] only says again what [sentence] says: the
/// processes sentence already counts processes, and the asking and combining
/// sentences already stand for the references.
bool _repeats(WorkingSentence sentence, WorkingCounterKind kind) =>
    switch (sentence.kind) {
      WorkingSentenceKind.processes => kind == WorkingCounterKind.processes,
      WorkingSentenceKind.askingModels ||
      WorkingSentenceKind.combiningAnswers =>
        kind == WorkingCounterKind.references,
      _ => false,
    };

/// What the activity line, or the Mac toolbar subtitle, says about the open
/// chat: the newest Working sentence and at most two counters, none of which
/// repeats the sentence.
///
/// Pure data from plain inputs. The Bot screen, usage and Needs-you items are
/// not Working items and have no way in. Null means nothing is working.
class WorkingSummary {
  const WorkingSummary({required this.sentence, this.counters = const []});

  final WorkingSentence sentence;

  /// The two that changed last, newest first.
  final List<WorkingCounter> counters;

  static const _maxCounters = 2;

  /// Folds the active Working sources.
  ///
  /// [sentences] are the sources that report one now. [planOpen] is whether
  /// the plan has a task that is not done or cancelled; it reads "Working on
  /// the plan" when no sentence is reported, and a plan counter is shown only
  /// while it is true. [counters] may hold any of the three kinds.
  static WorkingSummary? compute({
    Iterable<WorkingSentence> sentences = const [],
    bool planOpen = false,
    Iterable<WorkingCounter> counters = const [],
  }) {
    WorkingSentence? newest;
    for (final sentence in sentences) {
      if (!sentence._reportable) continue;
      if (newest == null || sentence.at >= newest.at) newest = sentence;
    }
    newest ??= planOpen
        ? const WorkingSentence(WorkingSentenceKind.plan, at: -1)
        : null;
    if (newest == null) return null;

    // The newest report of each kind decides, known or not: an older value
    // must not outlive a newer zero or unknown one.
    final latest = <WorkingCounterKind, WorkingCounter>{};
    for (final counter in counters) {
      final old = latest[counter.kind];
      if (old == null || counter.at >= old.at) latest[counter.kind] = counter;
    }
    final shown = [
      for (final counter in latest.values)
        if (counter._known &&
            !_repeats(newest, counter.kind) &&
            (counter.kind != WorkingCounterKind.plan ||
                (planOpen && counter.value! < counter.total!)))
          counter,
    ]..sort((a, b) => b.at.compareTo(a.at));
    return WorkingSummary(
      sentence: newest,
      counters: List.unmodifiable(shown.take(_maxCounters)),
    );
  }
}
