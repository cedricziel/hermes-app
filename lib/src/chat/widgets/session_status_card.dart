import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import '../chat_session_state.dart';

class SessionStatusCard extends StatelessWidget {
  const SessionStatusCard({
    super.key,
    required this.state,
    this.onDetails,
    this.onReopen,
    this.initiallyOpen = false,
  });
  final ChatSessionState state;
  final VoidCallback? onDetails;
  final VoidCallback? onReopen;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    if (!state.visible) return const SizedBox.shrink();
    final control = state.control;
    final summary = [
      if (state.reclaimedReason != null) 'Session reclaimed',
      if (state.resume case final progress?)
        'Restoring session: ${progress.phase} · ${progress.status}',
      if (control?.goal case final goal?)
        'Goal: ${goal['status'] ?? 'Unavailable'}',
      if (control?.loop case final loop?)
        'Loop: ${loop['status'] ?? 'Unavailable'}',
      if (control?.heartbeat case final heartbeat?)
        'Heartbeat: ${heartbeat['status'] ?? 'Unavailable'}',
      ...state.waits.values,
      if (state.unavailable) 'Session controls unavailable',
    ].join(' · ');
    return DisclosureTile(
      dense: true,
      initiallyExpanded: initiallyOpen,
      onExpansionChanged: (open) {
        if (open) onDetails?.call();
      },
      title: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.reclaimedReason case final reason?)
                SelectableText(
                  reason.isEmpty
                      ? 'Another client took control of this session.'
                      : reason,
                ),
              if (state.resume case final progress?) ...[
                Text('${progress.phase}: ${progress.status}'),
                if (progress.message case final message?)
                  SelectableText(message),
              ],
              if (control?.goal case final goal?)
                ..._section(context, 'Goal', goal, {
                  'title': 'Objective',
                  'status': 'Status',
                  'turns_used': 'Turns used',
                  'max_turns': 'Maximum turns',
                  'paused_reason': 'Paused reason',
                  'last_verdict': 'Last verdict',
                  'last_reason': 'Last reason',
                }),
              if (control?.loop case final loop?)
                ..._section(context, 'Loop', loop, {
                  'prompt': 'Prompt',
                  'status': 'Status',
                  'mode': 'Mode',
                  'ticks_fired': 'Ticks fired',
                  'max_ticks': 'Maximum ticks',
                  'interval_seconds': 'Interval in seconds',
                  'next_due_at': 'Next due',
                  'paused_reason': 'Paused reason',
                  'last_stop_reason': 'Last stop reason',
                }),
              if (control?.heartbeat case final heartbeat?)
                ..._section(context, 'Heartbeat', heartbeat, {
                  'prompt': 'Prompt',
                  'status': 'Status',
                  'fire_count': 'Fire count',
                  'interval_seconds': 'Interval in seconds',
                }),
              for (final text in state.waits.values) SelectableText(text),
              if (state.unavailable)
                const Text(
                  'This server could not provide session controls. Chat remains available.',
                ),
              if (onReopen != null &&
                  (state.reclaimedReason != null ||
                      state.resume?.status == 'failed'))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onReopen,
                    child: const Text('Reopen session'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    Map<String, Object?> values,
    Map<String, String> labels,
  ) => [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    for (final entry in labels.entries)
      if (values[entry.key] case final value?)
        SelectableText('${entry.value}: ${_value(context, entry.key, value)}'),
    const SizedBox(height: 8),
  ];

  String _value(BuildContext context, String key, Object value) {
    if (key == 'next_due_at' &&
        value is num &&
        value.isFinite &&
        value > 0 &&
        value < 8640000000) {
      final time = DateTime.fromMillisecondsSinceEpoch((value * 1000).round())
          .toLocal();
      final l10n = MaterialLocalizations.of(context);
      return '${l10n.formatShortDate(time)} ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
    }
    return value.toString();
  }
}
