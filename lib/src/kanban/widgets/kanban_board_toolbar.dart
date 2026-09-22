import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// The search field and filters over the board.
class KanbanBoardToolbar extends StatelessWidget {
  const KanbanBoardToolbar({
    super.key,
    required this.assignees,
    required this.tenants,
    required this.includeArchived,
    required this.wide,
    required this.onQueryChanged,
    required this.onAssigneeChanged,
    required this.onTenantChanged,
    required this.onIncludeArchivedChanged,
    this.assignee,
    this.tenant,
    this.onRefresh,
  });

  /// The assignees and tenants the board knows; an empty list hides its menu.
  final List<String> assignees;
  final List<String> tenants;

  /// The filters in effect; null means all.
  final String? assignee;
  final String? tenant;
  final bool includeArchived;

  /// A wide screen has no pull-to-refresh, so it gets a refresh button.
  final bool wide;

  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onAssigneeChanged;
  final ValueChanged<String?> onTenantChanged;
  final ValueChanged<bool> onIncludeArchivedChanged;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Search tasks',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kHermesRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: onQueryChanged,
                  ),
                ),
              ),
              if (wide)
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (assignees.isNotEmpty)
                  KanbanFilterMenu(
                    label: assignee ?? 'All assignees',
                    all: 'All assignees',
                    options: assignees,
                    onSelected: onAssigneeChanged,
                  ),
                if (tenants.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  KanbanFilterMenu(
                    label: tenant ?? 'All tenants',
                    all: 'All tenants',
                    options: tenants,
                    onSelected: onTenantChanged,
                  ),
                ],
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Archived'),
                  selected: includeArchived,
                  onSelected: onIncludeArchivedChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip that opens a menu of [options], with [all] (null) first.
class KanbanFilterMenu extends StatelessWidget {
  const KanbanFilterMenu({
    super.key,
    required this.label,
    required this.all,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String all;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem(value: null, child: Text(all)),
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.filter_list, size: 16),
      ),
    );
  }
}

/// Says the board on screen may be out of date, without covering it.
class KanbanRefreshFailedNotice extends StatelessWidget {
  const KanbanRefreshFailedNotice({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not refresh. Showing the last board.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
