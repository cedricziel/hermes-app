import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import 'tool_call_card.dart'
    show ToolCallStatusIcon, ToolCallTime, formatToolDuration;

/// The delegated subagents of one reply, in the spawn tree the events
/// rebuilt: a running child shows its live tool activity, a finished one its
/// summary, and the batch collapses behind a header naming what still runs —
/// the same fold as [ToolCallGroup], one level up.
///
/// A child whose [Subagent.parentId] names a known other child renders
/// indented beneath it; an unknown or missing parent makes a top-level
/// spawn, as the TUI's own tree builder renders older gateways flat.
class SubagentGroupCard extends StatefulWidget {
  const SubagentGroupCard({
    super.key,
    required this.subagents,
    this.initiallyOpen = false,
  });

  final List<Subagent> subagents;

  /// Starts with the details showing, as the catalog does to show them.
  final bool initiallyOpen;

  @override
  State<SubagentGroupCard> createState() => _SubagentGroupCardState();
}

class _SubagentGroupCardState extends State<SubagentGroupCard> {
  late var _open = widget.initiallyOpen;

  @override
  void didUpdateWidget(SubagentGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A batch that starts working again while folded stays visible, like a
    // run of tool calls waiting on the user does.
    if (!_open && _waiting(widget.subagents)) _open = true;
  }

  @override
  Widget build(BuildContext context) {
    final subagents = widget.subagents;
    if (subagents.length == 1) {
      return SubagentCard(subagent: subagents.single);
    }

    final running = subagents.where((s) => s.status == SubagentStatus.running);
    final waiting = _waiting(subagents);
    final label = waiting
        ? 'Running ${running.first.goal}…'
        : running.isNotEmpty
        ? '${subagents.length} agents · ${running.first.goal}…'
        : subagents.any((s) => s.status == SubagentStatus.failed)
        ? '${subagents.length} agents · ${subagents.where((s) => s.status == SubagentStatus.failed).length} failed'
        : 'Used ${subagents.length} agents';
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  ToolCallStatusIcon(
                    status: running.isNotEmpty
                        ? ToolCallStatus.running
                        : subagents.any(
                            (s) => s.status == SubagentStatus.failed,
                          )
                        ? ToolCallStatus.error
                        : subagents.every(
                            (s) => s.status == SubagentStatus.interrupted,
                          )
                        ? ToolCallStatus.cancelled
                        : ToolCallStatus.completed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (!waiting)
                    Text(
                      _totalDuration(subagents),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subtle,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_open) ..._tree(subagents),
        ],
      ),
    );
  }
}

bool _waiting(List<Subagent> subagents) =>
    subagents.any((s) => s.status == SubagentStatus.running);

/// The flat list as the spawn tree renders: children grouped beneath their
/// parent, a child deeper in the tree indented one more level.
List<Widget> _tree(List<Subagent> subagents) {
  final known = {for (final s in subagents) s.id};
  final byParent = <String, List<Subagent>>{};
  for (final s in subagents) {
    final key = s.parentId != null && known.contains(s.parentId)
        ? s.parentId!
        : '';
    (byParent[key] ??= []).add(s);
  }
  for (final bucket in byParent.values) {
    bucket.sort((a, b) => a.index.compareTo(b.index));
  }

  Widget buildNode(Subagent s, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 10.0 + depth * 16),
          child: SubagentCard(subagent: s),
        ),
        for (final child in byParent[s.id] ?? const [])
          buildNode(child, depth + 1),
      ],
    );
  }

  return [
    for (final root in byParent[''] ?? const <Subagent>[]) buildNode(root, 0),
  ];
}

/// The batch's wall time: the latest of the children that timed it.
String _totalDuration(List<Subagent> subagents) {
  final took = subagents.map((s) => s.duration).whereType<Duration>();
  if (took.isEmpty) return '';
  return formatToolDuration(took.reduce((a, b) => a > b ? a : b));
}

/// One delegated child: what it was asked to do, what it is doing right now
/// while it runs, and what it delivered once it finished.
class SubagentCard extends StatelessWidget {
  const SubagentCard({super.key, required this.subagent});

  final Subagent subagent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final s = subagent;
    final activity = switch (s.status) {
      SubagentStatus.running when s.lastTool != null =>
        '${s.lastTool} · ${s.lastToolPreview ?? s.goal}',
      SubagentStatus.running => s.goal,
      SubagentStatus.completed ||
      SubagentStatus.failed ||
      SubagentStatus.interrupted => s.summary ?? s.goal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 2),
          ToolCallStatusIcon(
            status: switch (s.status) {
              SubagentStatus.running => ToolCallStatus.running,
              SubagentStatus.completed => ToolCallStatus.completed,
              SubagentStatus.failed => ToolCallStatus.error,
              SubagentStatus.interrupted => ToolCallStatus.cancelled,
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.goal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
                ),
                if (s.status == SubagentStatus.running && s.lastTool != null)
                  Text(
                    activity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: subtle),
                  ),
                if (s.status != SubagentStatus.running && s.summary != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      activity,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: subtle),
                    ),
                  ),
              ],
            ),
          ),
          if (s.status == SubagentStatus.running && s.startedAt != null)
            ToolCallTime(
              call: ToolCall(
                name: '',
                summary: '',
                status: ToolCallStatus.running,
                startedAt: s.startedAt,
              ),
            )
          else if (s.duration != null)
            Text(
              formatToolDuration(s.duration!),
              style: TextStyle(
                fontSize: 11.5,
                color: subtle,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}
