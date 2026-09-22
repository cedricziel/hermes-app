import 'package:flutter/material.dart';

import '../../kanban_models.dart';
import 'kanban_task_heading.dart';

/// The home channels a task can post its updates to; nothing when there
/// are none.
class KanbanTaskChannels extends StatelessWidget {
  const KanbanTaskChannels({
    super.key,
    required this.channels,
    required this.onToggle,
    this.switching = const {},
  });

  final List<KanbanHomeChannel> channels;

  /// The platforms whose switch is waiting for the server.
  final Set<String> switching;
  final void Function(KanbanHomeChannel channel, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KanbanTaskHeading('Notify'),
        for (final c in channels)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Post updates to ${c.name}'),
            subtitle: Text(c.platform),
            value: c.subscribed,
            onChanged: switching.contains(c.platform)
                ? null
                : (on) => onToggle(c, on),
          ),
      ],
    );
  }
}
