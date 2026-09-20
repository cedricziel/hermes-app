/// The board's columns, left to right, as the plugin orders them. `archived`
/// is not a column but a filter that adds a ninth one.
const kanbanStatuses = [
  'triage',
  'todo',
  'scheduled',
  'ready',
  'running',
  'blocked',
  'review',
  'done',
];

String kanbanStatusLabel(String status) =>
    status.isEmpty ? status : status[0].toUpperCase() + status.substring(1);

DateTime? _time(Object? seconds) => seconds is num
    ? DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round())
    : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class KanbanTask {
  const KanbanTask({
    required this.id,
    required this.title,
    required this.status,
    this.body,
    this.assignee,
    this.priority = 0,
    this.tenant,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.latestSummary,
    this.commentCount = 0,
    this.parentCount = 0,
    this.childCount = 0,
    this.progressDone = 0,
    this.progressTotal = 0,
    this.warningCount = 0,
    this.warningSeverity,
  });

  /// Reads a task as the plugin serialises it on the board. Tolerates missing
  /// fields; the route declares no schema.
  factory KanbanTask.fromJson(Map<String, dynamic> json) {
    final links = json['link_counts'];
    final progress = json['progress'];
    final warnings = json['warnings'];
    return KanbanTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'todo',
      body: _text(json['body']),
      assignee: _text(json['assignee']),
      priority: _int(json['priority']),
      tenant: _text(json['tenant']),
      createdAt: _time(json['created_at']),
      startedAt: _time(json['started_at']),
      completedAt: _time(json['completed_at']),
      latestSummary: _text(json['latest_summary']),
      commentCount: _int(json['comment_count']),
      parentCount: links is Map ? _int(links['parents']) : 0,
      childCount: links is Map ? _int(links['children']) : 0,
      progressDone: progress is Map ? _int(progress['done']) : 0,
      progressTotal: progress is Map ? _int(progress['total']) : 0,
      warningCount: warnings is Map ? _int(warnings['count']) : 0,
      warningSeverity: warnings is Map
          ? _text(warnings['highest_severity'])
          : null,
    );
  }

  final String id;
  final String title;
  final String status;
  final String? body;
  final String? assignee;
  final int priority;
  final String? tenant;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? latestSummary;
  final int commentCount;
  final int parentCount;
  final int childCount;

  /// Children done and in total, when the task has children.
  final int progressDone;
  final int progressTotal;
  final int warningCount;
  final String? warningSeverity;
}

class KanbanColumn {
  const KanbanColumn({required this.name, required this.tasks});

  final String name;
  final List<KanbanTask> tasks;
}

class KanbanBoard {
  const KanbanBoard({
    required this.columns,
    this.tenants = const [],
    this.assignees = const [],
    this.latestEventId = 0,
  });

  factory KanbanBoard.fromJson(Map<String, dynamic> json) {
    List<String> names(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is String) e,
          ]
        : const [];
    final columns = json['columns'];
    return KanbanBoard(
      columns: [
        if (columns is List)
          for (final c in columns)
            if (c is Map)
              KanbanColumn(
                name: c['name'] as String? ?? '',
                tasks: [
                  for (final t in c['tasks'] as List? ?? const [])
                    if (t is Map<String, dynamic>) KanbanTask.fromJson(t),
                ],
              ),
      ],
      tenants: names(json['tenants']),
      assignees: names(json['assignees']),
      latestEventId: _int(json['latest_event_id']),
    );
  }

  final List<KanbanColumn> columns;
  final List<String> tenants;
  final List<String> assignees;

  /// The newest event this snapshot includes; the live stream resumes after it.
  final int latestEventId;

  int get taskCount => columns.fold(0, (n, c) => n + c.tasks.length);
}

/// One board of a Hermes install; each has its own tasks and workspaces.
class KanbanBoardInfo {
  const KanbanBoardInfo({
    required this.slug,
    required this.name,
    this.total = 0,
    this.isCurrent = false,
  });

  factory KanbanBoardInfo.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String? ?? '';
    return KanbanBoardInfo(
      slug: slug,
      name: _text(json['name']) ?? slug,
      total: _int(json['total']),
      isCurrent: json['is_current'] == true,
    );
  }

  final String slug;
  final String name;

  /// Live (non-archived) tasks.
  final int total;
  final bool isCurrent;
}
