/// A task as `GET /api/plugins/kanban/board` serialises it.
Map<String, Object?> kanbanTaskRow({
  required String id,
  String? title,
  String status = 'todo',
  String? assignee,
  int priority = 0,
  String? tenant,
  int commentCount = 0,
  Map<String, int>? progress,
  Map<String, Object?>? warnings,
}) => {
  'id': id,
  'title': title ?? 'Task $id',
  'status': status,
  'assignee': assignee,
  'priority': priority,
  'tenant': tenant,
  'created_at': 1780000000,
  'comment_count': commentCount,
  'link_counts': {'parents': 0, 'children': 0},
  'progress': progress,
  'warnings': ?warnings,
};

const _columns = [
  'triage',
  'todo',
  'scheduled',
  'ready',
  'running',
  'blocked',
  'review',
  'done',
];

/// The board body, grouping [tasks] into the plugin's columns.
Map<String, Object?> kanbanBoardBody(
  List<Map<String, Object?>> tasks, {
  int latestEventId = 0,
  List<String> tenants = const [],
}) => {
  'columns': [
    for (final name in _columns)
      {'name': name, 'tasks': tasks.where((t) => t['status'] == name).toList()},
  ],
  'tenants': tenants,
  'assignees': {
    for (final t in tasks)
      if (t['assignee'] != null) t['assignee'] as String,
  }.toList(),
  'latest_event_id': latestEventId,
  'now': 1780000100,
};

Map<String, Object?> kanbanBoardsBody(
  List<({String slug, String name, int total, bool current})> boards,
) => {
  'boards': [
    for (final b in boards)
      {
        'slug': b.slug,
        'name': b.name,
        'total': b.total,
        'is_current': b.current,
      },
  ],
  'current': boards.where((b) => b.current).firstOrNull?.slug,
};

/// `GET /api/plugins/kanban/tasks/{id}`.
Map<String, Object?> kanbanTaskDetailBody(
  Map<String, Object?> task, {
  List<Map<String, Object?>> comments = const [],
  List<String> parents = const [],
  List<Map<String, Object?>> events = const [],
}) => {
  'task': task,
  'comments': comments,
  'events': events,
  'attachments': <Object?>[],
  'links': {'parents': parents, 'children': <String>[]},
  'child_results': <Object?>[],
  'runs': <Object?>[],
};
