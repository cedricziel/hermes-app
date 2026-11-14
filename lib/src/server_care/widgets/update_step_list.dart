import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/disclosure_tile.dart';
import '../../widgets/grouped_list.dart';

enum UpdateStepState {
  pending('Waiting'),
  running('In progress'),
  done('Done'),
  failed('Failed');

  const UpdateStepState(this.word);

  /// What a screen reader says for the state; the icon alone never carries it.
  final String word;
}

class UpdateStep {
  const UpdateStep({required this.label, required this.state, this.subtitle});

  const UpdateStep.starting(this.state)
    : label = 'Starting the update',
      subtitle = null;

  const UpdateStep.installing(this.state)
    : label = 'Downloading and installing',
      subtitle = null;

  const UpdateStep.restarting(this.state)
    : label = 'Restarting Hermes',
      subtitle = "Chats continue when it's back.";

  const UpdateStep.checking(this.state)
    : label = 'Checking the result',
      subtitle = null;

  final String label;
  final String? subtitle;
  final UpdateStepState state;
}

/// The card shown while an update runs: a title, one row per step (icon and
/// word, the running one in semibold) and, as its last row, a "Show details"
/// disclosure with the last lines Hermes wrote.
class UpdateStepList extends StatelessWidget {
  const UpdateStepList({
    super.key,
    required this.steps,
    this.detailLines = const [],
    this.title = 'Updating…',
    this.detailsInitiallyOpen = false,
  });

  final List<UpdateStep> steps;

  /// Held in memory only; the disclosure is left out when empty.
  final List<String> detailLines;
  final String title;
  final bool detailsInitiallyOpen;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return GroupedSection(
      dividerIndent: metrics.indentAfterLeading,
      children: [
        _CardTitle(title: title),
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
    final subtitle = step.subtitle;
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
      label:
          '${step.label}, ${step.state.word}'
          '${subtitle == null ? '' : '. $subtitle'}',
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
                        step.label,
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
                          UpdateStepState.failed.word,
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

/// A "Show details" row that opens the last lines Hermes wrote, in monospace
/// and selectable. Shared by the step list and a failed update's outcome.
class UpdateDetailsDisclosure extends StatelessWidget {
  const UpdateDetailsDisclosure({
    super.key,
    required this.lines,
    this.initiallyOpen = false,
  });

  final List<String> lines;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DisclosureTile(
      initiallyExpanded: initiallyOpen,
      shape: const Border(),
      collapsedShape: const Border(),
      minTileHeight: metrics.rowMinHeight,
      tilePadding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
      childrenPadding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        0,
        metrics.rowPadding,
        metrics.rowPadding,
      ),
      title: Text(
        'Show details',
        style: TextStyle(fontSize: metrics.titleSize),
      ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: SelectableText(
                lines.join('\n'),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: metrics.footerSize,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
