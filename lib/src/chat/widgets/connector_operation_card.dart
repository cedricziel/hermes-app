import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import '../../../l10n/l10n.dart';
import '../connector_operation_controller.dart' show ConnectorAnswer;
import '../connector_operation_state.dart';

class ConnectorOperationCard extends StatelessWidget {
  const ConnectorOperationCard({
    super.key,
    required this.operation,
    this.initiallyOpen = false,
    this.readOnly = false,
    this.awaitingFinalStatus = false,
    this.pending = false,
    this.error,
    this.answer = ConnectorAnswer.idle,
    this.canOpen,
    this.canSkip,
    this.onOpen,
    this.onSkip,
    this.onContinue,
    this.onDetails,
  });

  final ConnectorOperationSnapshot operation;
  final bool initiallyOpen, awaitingFinalStatus, pending, readOnly;
  final String? error;

  /// Where the user's last answer stands; its words are localized here.
  final ConnectorAnswer answer;
  final bool Function(String)? canOpen, canSkip;
  final ValueChanged<String>? onOpen, onSkip;
  final VoidCallback? onContinue, onDetails;

  @override
  Widget build(BuildContext context) {
    final enabled =
        !readOnly && !operation.settled && !awaitingFinalStatus && !pending;
    final status = operation.settled
        ? 'Settled'
        : awaitingFinalStatus
        ? 'Awaiting final status'
        : pending
        ? 'Sending response'
        : 'Connection operation';
    return DisclosureTile(
      dense: true,
      initiallyExpanded: initiallyOpen,
      onExpansionChanged: (open) {
        if (open) onDetails?.call();
      },
      title: Text(status, maxLines: 2, overflow: TextOverflow.ellipsis),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ConnectorOperationBody(
            operation: operation,
            readOnly: readOnly,
            enabled: enabled,
            error: error,
            answer: answer,
            canOpen: canOpen,
            canSkip: canSkip,
            onOpen: onOpen,
            onSkip: onSkip,
            onContinue: onContinue,
          ),
        ),
      ],
    );
  }
}

/// The details inside [ConnectorOperationCard]: each target with its browser
/// destination, Open and Skip, then Continue. A plain-model widget; the card
/// passes whether the actions are [enabled].
class ConnectorOperationBody extends StatelessWidget {
  const ConnectorOperationBody({
    super.key,
    required this.operation,
    required this.enabled,
    this.readOnly = false,
    this.error,
    this.answer = ConnectorAnswer.idle,
    this.canOpen,
    this.canSkip,
    this.onOpen,
    this.onSkip,
    this.onContinue,
  });

  final ConnectorOperationSnapshot operation;
  final bool enabled, readOnly;
  final String? error;

  /// Where the user's last answer stands; its words are localized here.
  final ConnectorAnswer answer;
  final bool Function(String)? canOpen, canSkip;
  final ValueChanged<String>? onOpen, onSkip;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (readOnly) const Text('Read-only operation.'),
        if (operation.targets.isEmpty)
          const Text('No connection targets reported.'),
        for (final target in operation.targets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(target.name),
                Text('${target.action} · ${target.state}'),
                if (target.detail case final detail?) SelectableText(detail),
                if (target.instructions case final instructions?)
                  SelectableText(instructions),
                if (!target.canCompleteHere)
                  const Text('This target cannot be completed in this app.'),
                if (target.browserUri case final uri? when !readOnly)
                  Text('Browser destination: ${uri.host}'),
                if (!readOnly &&
                    target.connectUrl != null &&
                    target.browserUri == null &&
                    target.canCompleteHere)
                  const Text('Browser opening unavailable.'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (!readOnly &&
                        target.browserUri != null &&
                        onOpen != null)
                      TextButton(
                        onPressed: enabled && canOpen?.call(target.name) == true
                            ? () => onOpen!(target.name)
                            : null,
                        child: const Text('Open connection'),
                      ),
                    if (!readOnly && target.supportsSkip && onSkip != null)
                      TextButton(
                        onPressed: enabled && canSkip?.call(target.name) == true
                            ? () => onSkip!(target.name)
                            : null,
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (error case final text?) Text(text),
        if (answer == ConnectorAnswer.unconfirmed)
          Text(context.l10n.chatActivityNeedsYouUnconfirmedNotice),
        if (answer == ConnectorAnswer.refused)
          Text(context.l10n.chatActivityNeedsYouRefusedNotice),
        if (operation.settledBy case final reason?) Text('Settlement: $reason'),
        if (!readOnly && onContinue != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: enabled ? onContinue : null,
              child: const Text('Continue'),
            ),
          ),
      ],
    );
  }
}
