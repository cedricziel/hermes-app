import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/output_lines_tile.dart';

enum UpdateStepState {
  pending,
  running,
  done,
  failed;

  /// What a screen reader says for the state; the icon alone never carries it.
  String word(AppLocalizations l10n) => switch (this) {
    pending => l10n.serverCareUpdateStepStateWaiting,
    running => l10n.serverCareUpdateStepStateInProgress,
    done => l10n.serverCareUpdateStepStateDone,
    failed => l10n.serverCareUpdateStepStateFailed,
  };
}

/// The four steps of an update, worded by the widget.
enum UpdateStepKind { starting, installing, restarting, checking }

class UpdateStep {
  /// A step with its own words, already in the reader's language.
  const UpdateStep({
    required String this.label,
    required this.state,
    this.subtitle,
  }) : kind = null;

  const UpdateStep.starting(this.state)
    : kind = UpdateStepKind.starting,
      label = null,
      subtitle = null;

  const UpdateStep.installing(this.state)
    : kind = UpdateStepKind.installing,
      label = null,
      subtitle = null;

  const UpdateStep.restarting(this.state)
    : kind = UpdateStepKind.restarting,
      label = null,
      subtitle = null;

  const UpdateStep.checking(this.state)
    : kind = UpdateStepKind.checking,
      label = null,
      subtitle = null;

  final UpdateStepKind? kind;
  final String? label;
  final String? subtitle;
  final UpdateStepState state;

  String labelOf(AppLocalizations l10n) =>
      label ??
      switch (kind!) {
        UpdateStepKind.starting => l10n.serverCareUpdateStepStarting,
        UpdateStepKind.installing => l10n.serverCareUpdateStepInstalling,
        UpdateStepKind.restarting => l10n.serverCareUpdateStepRestarting,
        UpdateStepKind.checking => l10n.serverCareUpdateStepChecking,
      };

  String? subtitleOf(AppLocalizations l10n) =>
      subtitle ??
      (kind == UpdateStepKind.restarting
          ? l10n.serverCareUpdateStepRestartingNote
          : null);
}

/// The card shown while an update runs: a title, one row per step (icon and
/// word, the running one in semibold) and, as its last row, a "Show details"
/// disclosure with the last lines Hermes wrote.
class UpdateStepList extends StatelessWidget {
  const UpdateStepList({
    super.key,
    required this.steps,
    this.detailLines = const [],
    this.title,
    this.detailsInitiallyOpen = false,
  });

  final List<UpdateStep> steps;

  /// Held in memory only; the disclosure is left out when empty.
  final List<String> detailLines;

  /// Defaults to "Updating…".
  final String? title;
  final bool detailsInitiallyOpen;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return GroupedSection(
      dividerIndent: metrics.indentAfterLeading,
      children: [
        _CardTitle(title: title ?? context.l10n.serverCareUpdateStepListTitle),
        for (final step in steps) _StepRow(step: step),
        if (detailLines.isNotEmpty)
          UpdateDetailsDisclosure(
            lines: detailLines,
            initiallyOpen: detailsInitiallyOpen,
          ),
      ],
    );
  }
}

/// The card's own title, not a section header: it is part of the card.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.rowPadding,
          vertical: metrics.rowVerticalPadding + 4,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            title,
            style: TextStyle(
              fontSize: metrics.titleSize + 2,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final UpdateStep step;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final running = step.state == UpdateStepState.running;
    final l10n = context.l10n;
    final subtitle = step.subtitleOf(l10n);
    final label = step.labelOf(l10n);
    final stateWord = step.state.word(l10n);
    final icon = switch (step.state) {
      UpdateStepState.pending => AppIcon(
        AppIcons.radioOff,
        size: metrics.leadingSize,
        color: colors.subtleText,
      ),
      UpdateStepState.running => SizedBox.square(
        dimension: metrics.leadingSize,
        // A spinner stays under reduced motion: it carries the state.
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: scheme.onSurface,
          ),
        ),
      ),
      UpdateStepState.done => AppIcon(
        AppIcons.checkCircleFilled,
        size: metrics.leadingSize,
        color: colors.success,
      ),
      UpdateStepState.failed => AppIcon(
        AppIcons.errorFilled,
        size: metrics.leadingSize,
        color: scheme.error,
      ),
    };
    return Semantics(
      container: true,
      label: subtitle == null
          ? l10n.serverCareUpdateStepLabelState(label, stateWord)
          : l10n.serverCareUpdateStepLabelStateNote(label, stateWord, subtitle),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowPadding,
              vertical: metrics.rowVerticalPadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: icon),
                SizedBox(width: metrics.leadingGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: metrics.titleSize,
                          fontWeight: running
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: scheme.onSurface,
                        ),
                      ),
                      // A failure is said in words as well as by its icon.
                      if (step.state == UpdateStepState.failed)
                        Text(
                          stateWord,
                          style: TextStyle(
                            fontSize: metrics.subtitleSize,
                            fontWeight: FontWeight.w600,
                            color: scheme.error,
                          ),
                        ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: metrics.subtitleSize,
                            color: colors.subtleText,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A "Show details" row that opens the last lines Hermes wrote. Shared by the
/// step list and a failed update's outcome.
class UpdateDetailsDisclosure extends StatelessWidget {
  const UpdateDetailsDisclosure({
    super.key,
    required this.lines,
    this.initiallyOpen = false,
  });

  final List<String> lines;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) => OutputLinesTile(
    label: context.l10n.serverCareUpdateDetailsShow,
    lines: lines,
    initiallyOpen: initiallyOpen,
  );
}
