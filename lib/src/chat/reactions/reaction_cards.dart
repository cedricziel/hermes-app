import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import 'reaction_state.dart';

class MessageReactionCard extends StatelessWidget {
  const MessageReactionCard({
    super.key,
    required this.reactions,
    this.initiallyOpen = false,
    this.onDetails,
  });
  final List<ReportedReaction>? reactions;
  final bool initiallyOpen;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) {
    final values = reactions;
    if (values == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Reaction details unavailable'),
      );
    }
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              for (final value in values)
                Text('${value.emoji} · ${value.author}'),
            ],
          ),
        ),
        DisclosureTile(
          dense: true,
          title: const Text('Message reactions'),
          initiallyExpanded: initiallyOpen,
          onExpansionChanged: (open) {
            if (open) onDetails?.call();
          },
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final value in values)
                        SelectableText('Author: ${value.author}'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SessionAcknowledgementCard extends StatelessWidget {
  const SessionAcknowledgementCard({
    super.key,
    required this.acknowledgement,
    this.initiallyOpen = false,
    this.onDetails,
  });
  final SessionAcknowledgement? acknowledgement;
  final bool initiallyOpen;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) => acknowledgement == null
      ? const SizedBox.shrink()
      : DisclosureTile(
          dense: true,
          title: const Text('Session acknowledgement'),
          initiallyExpanded: initiallyOpen,
          onExpansionChanged: (open) {
            if (open) onDetails?.call();
          },
          children: const [
            Padding(
              padding: EdgeInsets.all(12),
              child: Text('An acknowledgement was reported for this session.'),
            ),
          ],
        );
}
