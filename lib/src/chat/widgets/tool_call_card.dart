import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';

/// A compact, collapsed-by-default summary of a tool the agent ran —
/// assistant-ui surfaces tool calls as their own inline card rather than
/// mixing them into the message prose, so the reasoning stays scannable.
class ToolCallCard extends StatelessWidget {
  const ToolCallCard({super.key, required this.call});

  final ToolCall call;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusIcon(status: call.status),
          const SizedBox(width: 8),
          Text(
            call.name,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              call.summary,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: context.hermesColors.subtleText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final ToolCallStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ToolCallStatus.running:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ToolCallStatus.completed:
        return const Icon(
          Icons.check_circle,
          size: 14,
          color: Color(0xFF16A34A),
        );
      case ToolCallStatus.error:
        return Icon(
          Icons.error,
          size: 14,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}
