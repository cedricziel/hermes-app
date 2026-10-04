import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/state_message.dart';

/// The width of the Mac board's inspector.
const double kKanbanInspectorWidth = 380;

/// Below this width the inspector covers the board instead of sitting beside
/// it.
const double kKanbanInspectorDockedMinWidth = 760;

/// The board with the inspector on its right, as in a Mac app: docked beside
/// the board in a wide window, over it from the right in a narrow one.
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inspector = this.inspector;
      final docked = constraints.maxWidth >= kKanbanInspectorDockedMinWidth;
      if (docked) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: board),
            if (shown)
              _Panel(
                overlay: false,
                child: inspector ?? const KanbanInspectorPlaceholder(),
              ),
          ],
        );
      }
      return Stack(
        children: [
          Positioned.fill(child: board),
          if (shown && inspector != null)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: constraints.maxWidth < kKanbanInspectorWidth
                  ? constraints.maxWidth
                  : kKanbanInspectorWidth,
              child: _Panel(overlay: true, child: inspector),
            ),
        ],
      );
    },
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.overlay, required this.child});

  final bool overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('kanban-inspector'),
      width: kKanbanInspectorWidth,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(left: BorderSide(color: theme.dividerColor)),
        boxShadow: overlay
            ? [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(-4, 0),
                ),
              ]
            : null,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
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
