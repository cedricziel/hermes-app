import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../queued_prompt.dart';

/// The prompts waiting for the thread's reply to end, shown above the
/// composer. [onSendNow] is given while the queue is paused, after a stopped
/// or failed reply, and sends the first prompt.
class QueuedPrompts extends StatelessWidget {
  const QueuedPrompts({
    super.key,
    required this.prompts,
    required this.onRemove,
    this.onSendNow,
  });

  final List<QueuedPrompt> prompts;
  final ValueChanged<QueuedPrompt> onRemove;
  final VoidCallback? onSendNow;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final onSendNow = this.onSendNow;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  onSendNow == null
                      ? 'Queued, sent when Hermes is done'
                      : 'Queue paused',
                  style: TextStyle(color: subtle),
                ),
              ),
              if (onSendNow != null)
                TextButton.icon(
                  onPressed: onSendNow,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send now'),
                ),
            ],
          ),
          for (final prompt in prompts)
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: subtle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _label(prompt),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (prompt.files.isNotEmpty && prompt.text.isNotEmpty) ...[
                  Icon(Icons.attach_file, size: 16, color: subtle),
                  Text(
                    '${prompt.files.length}',
                    style: TextStyle(color: subtle),
                  ),
                ],
                IconButton(
                  tooltip: 'Remove from queue',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemove(prompt),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _label(QueuedPrompt prompt) => prompt.text.isNotEmpty
      ? prompt.text
      : prompt.files.map((f) => f.name).join(', ');
}
