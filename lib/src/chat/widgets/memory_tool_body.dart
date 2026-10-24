import 'package:flutter/material.dart';

import '../../memory/memory_decisions.dart';
import '../../memory/memory_tool_outcome.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import 'tool_call_bodies.dart';

/// Gives the memory cards of a chat the decisions of its staged writes.
/// Without one, as in the catalog, the buttons are left out.
class MemoryDecisionsScope extends InheritedNotifier<MemoryDecisions> {
  const MemoryDecisionsScope({
    super.key,
    required MemoryDecisions? decisions,
    required super.child,
  }) : super(notifier: decisions);

  static MemoryDecisions? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MemoryDecisionsScope>()
      ?.notifier;
}

/// What an opened `memory` call shows: the text it saved, the text it waits
/// for the user to approve, or that the file was full.
class MemoryToolBody extends StatelessWidget {
  const MemoryToolBody({
    super.key,
    required this.outcome,
    this.decision = MemoryDecisionState.idle,
    this.onDecide,
  });

  final MemoryToolOutcome outcome;

  /// Where the user's decision on a staged write stands.
  final MemoryDecisionState decision;

  /// Approves (true) or rejects (false) a staged write; null leaves the
  /// buttons out.
  final ValueChanged<bool>? onDecide;

  /// The body for [call], or null when its result is not a memory outcome.
  static Widget? of(ToolCall call) {
    final outcome = MemoryToolOutcome.parse(
      args: call.args,
      result: call.resultData,
    );
    return outcome == null ? null : _BoundMemoryToolBody(outcome);
  }

  String _saved(int? percent) =>
      'Saved to memory · ${outcome.tab}'
      '${percent == null ? '' : ' · $percent% full'}';

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final scheme = Theme.of(context).colorScheme;
    final waiting =
        outcome.kind == MemoryOutcomeKind.staged &&
        decision.phase != MemoryDecisionPhase.saved &&
        decision.phase != MemoryDecisionPhase.rejected;
    final summary = switch (outcome.kind) {
      MemoryOutcomeKind.saved => _saved(outcome.percent),
      MemoryOutcomeKind.staged
          when decision.phase == MemoryDecisionPhase.saved =>
        _saved(null),
      MemoryOutcomeKind.staged
          when decision.phase == MemoryDecisionPhase.rejected =>
        'Rejected · ${outcome.tab}',
      _ => null,
    };
    final running = decision.phase == MemoryDecisionPhase.running;
    return ToolBodyFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (outcome.kind == MemoryOutcomeKind.full)
            _Warning(
              '${outcome.tab} ${outcome.tab == 'About you' ? 'is' : 'are'} at '
              '${outcome.used} of ${outcome.limit} characters, so this entry '
              'did not fit. Nothing was saved; Hermes usually makes room and '
              'tries again.',
            )
          else ...[
            if (summary != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            for (final block in outcome.blocks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in block)
                      SelectableText(
                        '${line.added ? '+' : '−'} ${line.text}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: line.added ? colors.success : scheme.error,
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (waiting) ...[
            Text(
              'Not saved yet.',
              style: TextStyle(color: colors.subtleText, fontSize: 12.5),
            ),
            if (decision.phase == MemoryDecisionPhase.failed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  decision.text,
                  style: TextStyle(color: scheme.error, fontSize: 12.5),
                ),
              ),
            if (onDecide != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: running ? null : () => onDecide!(false),
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: running ? null : () => onDecide!(true),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.hermesColors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: AppIcon(AppIcons.warning, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12.5, color: color)),
        ),
      ],
    );
  }
}

class _BoundMemoryToolBody extends StatelessWidget {
  const _BoundMemoryToolBody(this.outcome);

  final MemoryToolOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final decisions = MemoryDecisionsScope.maybeOf(context);
    final id = outcome.pendingId;
    return MemoryToolBody(
      outcome: outcome,
      decision: id == null || decisions == null
          ? MemoryDecisionState.idle
          : decisions.stateOf(id),
      onDecide: id == null || decisions == null || !decisions.available()
          ? null
          : (approve) => decisions.decide(id, approve: approve),
    );
  }
}
