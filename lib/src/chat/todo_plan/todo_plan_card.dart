import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import 'todo_plan_state.dart';

class TodoPlanCard extends StatelessWidget {
  const TodoPlanCard({
    super.key,
    required this.state,
    this.initiallyOpen = false,
  });
  final TodoPlanState state;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final snapshot = state.snapshot;
      if (!state.hasPlan || snapshot == null) return const SizedBox.shrink();
      final completed = snapshot.completedCount;
      final title = completed == null
          ? 'Plan · Some task details unavailable'
          : 'Plan · $completed of ${snapshot.entries.length} completed';
      return DisclosureTile(
        initiallyExpanded: initiallyOpen,
        dense: true,
        onExpansionChanged: (open) {
          if (open) state.detailsOpened();
        },
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in snapshot.entries)
                      if (entry == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Task details unavailable'),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            entry.parent == null ? 0 : 12,
                            0,
                            0,
                            12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(switch (entry.status) {
                                TodoStatus.pending => 'Pending',
                                TodoStatus.inProgress => 'In progress',
                                TodoStatus.completed => 'Completed',
                                TodoStatus.cancelled => 'Cancelled',
                              }, style: Theme.of(context).textTheme.labelSmall),
                              SelectableText(entry.content),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
