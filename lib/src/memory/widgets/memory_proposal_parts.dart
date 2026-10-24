import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../memory_proposals.dart';

/// What Hermes would do, in a small tinted label.
class ProposalBadge extends StatelessWidget {
  const ProposalBadge(this.action, {super.key});

  final ProposalAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (action) {
      ProposalAction.add => colors.success,
      ProposalAction.remove => scheme.error,
      ProposalAction.replace => colors.warning,
      ProposalAction.skill => scheme.primary,
      ProposalAction.change => colors.subtleText,
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// "About you · from a background review": where the change goes and what
/// staged it. Hermes keeps no date or chat name for a proposal, so there is
/// neither.
String proposalOrigin(MemoryProposal proposal) {
  final origin = proposal.background
      ? 'from a background review'
      : 'from a chat';
  final target = proposal.targetLabel;
  return target == null ? origin : '$target · $origin';
}

/// A shortened first line of what a proposal says, for a list row.
String proposalPreview(MemoryProposal proposal) =>
    proposal.newText ??
    proposal.replaced.firstOrNull ??
    proposal.summary.split('\n').first;
