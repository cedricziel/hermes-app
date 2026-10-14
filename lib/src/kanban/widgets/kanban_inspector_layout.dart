import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/inspector_layout.dart';
import '../../widgets/state_message.dart';

/// The width of the Mac board's inspector.
const double kKanbanInspectorWidth = kInspectorWidth;

/// The board with the inspector on its right ([InspectorLayout]).
///
/// A docked inspector without a task says how to pick one; an overlay shows
/// only once there is a task to show.
class KanbanInspectorLayout extends StatelessWidget {
  const KanbanInspectorLayout({
    super.key,
    required this.board,
    required this.shown,
    this.inspector,
  });

  final Widget board;

  /// Whether the inspector is on, from its toolbar toggle.
  final bool shown;

  /// The open task's panel, or null when no task is open.
  final Widget? inspector;

  @override
  Widget build(BuildContext context) => InspectorLayout(
    content: board,
    shown: shown,
    inspector: inspector,
    placeholder: const KanbanInspectorPlaceholder(),
    panelKey: const Key('kanban-inspector'),
  );
}

/// What a docked inspector says before a task is picked.
class KanbanInspectorPlaceholder extends StatelessWidget {
  const KanbanInspectorPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const StateMessage(
    icon: AppIcons.inspector,
    title: 'No task selected',
    detail: 'Click a card to see its details here.',
  );
}
