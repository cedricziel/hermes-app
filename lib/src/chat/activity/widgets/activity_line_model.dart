import '../../../../l10n/l10n.dart';
import '../working_summary.dart';

enum ActivityCounterKind { plan, processes, references }

/// One counter chip: the [text] it shows and the [label] a screen reader
/// speaks.
class ActivityLineCounter {
  const ActivityLineCounter({
    required this.kind,
    required this.text,
    required this.label,
  });

  final ActivityCounterKind kind;
  final String text, label;
}

/// What the activity line shows. The [sentence] is already in words: the
/// server's own text, untranslated, or one of the app's phrases.
class ActivityLineModel {
  const ActivityLineModel({
    required this.sentence,
    this.counters = const [],
    this.busy = true,
  }) : assert(counters.length <= 2, 'The line shows at most two counters.');

  final String sentence;
  final List<ActivityLineCounter> counters;

  /// Whether the progress indicator is drawn.
  final bool busy;

  /// The sentence for a screen reader: a closing ellipsis or full stop would
  /// only be read as a pause before ", plan 2 of 5" or ". Opens activity.".
  String get spokenSentence {
    final trimmed = sentence.replaceFirst(
      RegExp(r'(\s*(…|\.\.\.|\.))+\s*$'),
      '',
    );
    return trimmed.isEmpty ? sentence : trimmed;
  }

  /// The line for [summary]. [AppLocalizations] is the only place the
  /// sentence kinds become words.
  factory ActivityLineModel.fromSummary(
    AppLocalizations l10n,
    WorkingSummary summary,
  ) => ActivityLineModel(
    sentence: workingSentenceText(l10n, summary.sentence),
    counters: [for (final counter in summary.counters) _counter(l10n, counter)],
  );
}

/// The words for [sentence].
String workingSentenceText(AppLocalizations l10n, WorkingSentence sentence) =>
    switch (sentence.kind) {
      WorkingSentenceKind.status ||
      WorkingSentenceKind.goal => sentence.text?.trim() ?? '',
      WorkingSentenceKind.processes => l10n.chatActivityLineProcesses(
        sentence.count ?? 1,
      ),
      WorkingSentenceKind.askingModels => switch (sentence.count) {
        final count? => l10n.chatActivityLineAsking(count),
        null => l10n.chatActivityLineAskingUnknown,
      },
      WorkingSentenceKind.combiningAnswers => l10n.chatActivityLineCombining,
      WorkingSentenceKind.restoring => l10n.chatActivityLineRestoring,
      WorkingSentenceKind.plan => l10n.chatActivityLinePlan,
    };

ActivityLineCounter _counter(AppLocalizations l10n, WorkingCounter counter) {
  final value = counter.value ?? 0, total = counter.total ?? 0;
  return switch (counter.kind) {
    WorkingCounterKind.plan => ActivityLineCounter(
      kind: ActivityCounterKind.plan,
      text: l10n.chatActivityLinePlanCounter(value, total),
      label: l10n.chatActivityLinePlanCounterLabel(value, total),
    ),
    WorkingCounterKind.processes => ActivityLineCounter(
      kind: ActivityCounterKind.processes,
      text: l10n.chatActivityLineProcessesCounter(value),
      label: l10n.chatActivityLineProcessesCounterLabel(value),
    ),
    WorkingCounterKind.references => ActivityLineCounter(
      kind: ActivityCounterKind.references,
      text: l10n.chatActivityLineReferencesCounter(value, total),
      label: l10n.chatActivityLineReferencesCounterLabel(value, total),
    ),
  };
}
