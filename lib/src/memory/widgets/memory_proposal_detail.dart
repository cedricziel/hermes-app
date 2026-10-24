import 'package:flutter/material.dart';

import '../../chat/widgets/tool_call_bodies.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../memory_decisions.dart';
import '../memory_proposals.dart';
import '../memory_proposals_controller.dart';
import 'memory_proposal_parts.dart';

/// Shown under a proposal whose new text Hermes may have cut.
const kProposalShortenedNote =
    'Long new text is shortened in this list; approving applies all of it.';

/// One proposal in full: what it changes and where it came from, the entries
/// it replaces struck through, the new text, and the buttons. [decision] is
/// where the user's decision on it stands; [diff] is a skill's changes once
/// asked for with [onShowChanges].
class MemoryProposalDetail extends StatelessWidget {
  const MemoryProposalDetail({
    super.key,
    required this.proposal,
    this.decision = MemoryDecisionState.idle,
    this.diff,
    this.busy = false,
    this.onApprove,
    this.onReject,
    this.onShowChanges,
  });

  final MemoryProposal proposal;
  final MemoryDecisionState decision;
  final ProposalDiff? diff;

  /// Another decision is running, so these buttons wait.
  final bool busy;
  final VoidCallback? onApprove, onReject, onShowChanges;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final scheme = Theme.of(context).colorScheme;
    final text = proposal.newText;
    final enabled = decision.canDecide && !busy;
    const style = TextStyle(fontSize: 14, height: 1.35);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ProposalBadge(proposal.action),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                proposalOrigin(proposal),
                style: TextStyle(color: colors.subtleText, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in proposal.replaced)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SelectableText(
              '− $entry',
              style: style.copyWith(
                color: scheme.error,
                decoration: TextDecoration.lineThrough,
                decorationColor: scheme.error,
              ),
            ),
          ),
        if (text != null)
          SelectableText(
            '+ $text',
            style: style.copyWith(color: colors.success),
          )
        else if (proposal.action == ProposalAction.change)
          SelectableText(proposal.summary, style: style),
        if (proposal.mayBeShortened)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              kProposalShortenedNote,
              style: TextStyle(color: colors.subtleText, fontSize: 12.5),
            ),
          ),
        if (proposal.warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: AppIcon(
                    AppIcons.warning,
                    size: 14,
                    color: colors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    proposal.warning!,
                    style: TextStyle(color: colors.warning, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        if (proposal.kind == ProposalKind.skill) _changes(context),
        if (decision.phase == MemoryDecisionPhase.failed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              decision.text,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              key: const Key('proposal-reject'),
              onPressed: enabled ? onReject : null,
              child: const Text('Reject'),
            ),
            FilledButton(
              key: const Key('proposal-approve'),
              onPressed: enabled ? onApprove : null,
              child: const Text('Approve'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _changes(BuildContext context) {
    final shown = diff;
    final subtle = context.hermesColors.subtleText;
    if (shown == null || shown.failed) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('proposal-show-changes'),
            onPressed: onShowChanges,
            child: Text(
              shown == null ? 'Show changes' : "Couldn't load. Try again",
            ),
          ),
        ),
      );
    }
    if (shown.loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );
    }
    final body = shown.text ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: body.contains('\n@@') || body.startsWith('@@')
          ? ToolDiffBody(diff: body)
          : ToolBodyFrame(
              child: SelectableText(
                body,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: subtle,
                ),
              ),
            ),
    );
  }
}
