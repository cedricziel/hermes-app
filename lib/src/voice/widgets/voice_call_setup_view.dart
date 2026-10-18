import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../calls/call_readiness.dart';

/// Plain readiness state and explicit actions, independent of call ownership.
class VoiceCallSetupView extends StatelessWidget {
  const VoiceCallSetupView({
    super.key,
    required this.readiness,
    required this.onClose,
    required this.onRetry,
    required this.onStart,
    this.onMicrophone,
    this.onDictation,
    this.onAskHermes,
    this.busy = false,
    this.microphoneDenied = false,
    this.error,
  });
  final CallReadiness readiness;
  final VoidCallback onClose, onRetry, onStart;
  final VoidCallback? onMicrophone, onDictation, onAskHermes;
  final bool busy, microphoneDenied;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checking = readiness.isChecking;
    final disabled = checking || busy;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onClose,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(height: 24),
                Icon(
                  CupertinoIcons.phone,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(
                    checking
                        ? 'Getting your call ready'
                        : readiness.ready
                        ? 'Ready to call'
                        : 'Set up voice calls',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  checking
                      ? 'Checking this device and your Hermes speech settings.'
                      : readiness.ready
                      ? 'Your microphone and speech settings are ready.'
                      : 'A few things need attention before you can call Hermes.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < readiness.checks.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 48),
                        _CheckRow(check: readiness.checks[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (error != null) ...[
                  Text(
                    error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!checking) ...[
                  if (readiness.checks.any(
                    (c) => c.action == CallSetupAction.microphone,
                  ))
                    OutlinedButton(
                      onPressed: disabled ? null : onMicrophone,
                      child: Text(
                        microphoneDenied
                            ? 'Open iOS Settings'
                            : 'Allow microphone',
                      ),
                    ),
                  if (readiness.checks.any(
                    (c) => c.action == CallSetupAction.dictation,
                  ))
                    OutlinedButton(
                      onPressed: disabled ? null : onDictation,
                      child: const Text('Open Dictation settings'),
                    ),
                  if (readiness.canAskHermes) ...[
                    FilledButton(
                      onPressed: disabled ? null : onAskHermes,
                      child: const Text('Ask Hermes to set this up'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sends a setup request in this chat. Hermes will ask before changing your server.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (readiness.ready)
                    FilledButton(
                      onPressed: disabled ? null : onStart,
                      child: const Text('Start call'),
                    )
                  else
                    TextButton(
                      onPressed: disabled ? null : onRetry,
                      child: const Text('Check again'),
                    ),
                ],
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final CallCheck check;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = check.status == CallCheckStatus.ready;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (check.status == CallCheckStatus.checking)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: CupertinoActivityIndicator(radius: 9),
            )
          else
            Icon(
              ready
                  ? CupertinoIcons.check_mark_circled
                  : CupertinoIcons.exclamationmark_circle,
              size: 20,
              color: ready
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  check.detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
