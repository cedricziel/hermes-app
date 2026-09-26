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
    this.result,
    this.commentCount = 0,
    this.parentCount = 0,
    this.childCount = 0,
    this.progressDone = 0,
    this.progressTotal = 0,
    this.warningCount = 0,
    this.warningSeverity,
    this.modelOverride,
    this.providerOverride,
    this.reasoningEffort,
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
      result: _text(json['result']),
      commentCount: _int(json['comment_count']),
      parentCount: links is Map ? _int(links['parents']) : 0,
      childCount: links is Map ? _int(links['children']) : 0,
      progressDone: progress is Map ? _int(progress['done']) : 0,
      progressTotal: progress is Map ? _int(progress['total']) : 0,
      warningCount: warnings is Map ? _int(warnings['count']) : 0,
      warningSeverity: warnings is Map
          ? _text(warnings['highest_severity'])
          : null,
      modelOverride: _text(json['model_override']),
      providerOverride: _text(json['provider_override']),
      reasoningEffort: _text(json['reasoning_effort']),
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
  final String? result;
  final int commentCount;
  final int parentCount;
  final int childCount;

  /// Children done and in total, when the task has children.
  final int progressDone;
  final int progressTotal;
  final int warningCount;
  final String? warningSeverity;

  /// The model, its provider and the reasoning effort the task runs on
  /// instead of its profile's; null where the profile decides.
  final String? modelOverride;
  final String? providerOverride;
  final String? reasoningEffort;

  /// This task in another column, everything else as it was.
  KanbanTask withStatus(String status) => KanbanTask(
    id: id,
    title: title,
    status: status,
    body: body,
    assignee: assignee,
    priority: priority,
    tenant: tenant,
    createdAt: createdAt,
    startedAt: startedAt,
    completedAt: completedAt,
    latestSummary: latestSummary,
    result: result,
    commentCount: commentCount,
    parentCount: parentCount,
    childCount: childCount,
    progressDone: progressDone,
    progressTotal: progressTotal,
    warningCount: warningCount,
    warningSeverity: warningSeverity,
    modelOverride: modelOverride,
    providerOverride: providerOverride,
    reasoningEffort: reasoningEffort,
  );
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

class KanbanComment {
  const KanbanComment({
    required this.author,
    required this.body,
    this.createdAt,
  });

  factory KanbanComment.fromJson(Map<String, dynamic> json) => KanbanComment(
    author: json['author'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: _time(json['created_at']),
  );

  final String author;
  final String body;
  final DateTime? createdAt;
}

/// One entry of a task's history, such as `created`, `blocked` or `completed`.
class KanbanEvent {
  const KanbanEvent({required this.kind, this.createdAt, this.payload});

  factory KanbanEvent.fromJson(Map<String, dynamic> json) => KanbanEvent(
    kind: json['kind'] as String? ?? '',
    createdAt: _time(json['created_at']),
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : null,
  );

  final String kind;
  final DateTime? createdAt;
  final Map<String, dynamic>? payload;
}

/// A child task's outcome, shown on the parent that waited for it.
class KanbanChildResult {
  const KanbanChildResult({
    required this.id,
    required this.title,
    required this.status,
    this.summary,
  });

  factory KanbanChildResult.fromJson(Map<String, dynamic> json) =>
      KanbanChildResult(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? '',
        summary: _text(json['latest_summary']) ?? _text(json['result']),
      );

  final String id;
  final String title;
  final String status;
  final String? summary;
}

/// One attempt at a task by a worker.
class KanbanRun {
  const KanbanRun({
    required this.id,
    required this.status,
    this.profile,
    this.outcome,
    this.summary,
    this.error,
    this.startedAt,
    this.endedAt,
  });

  factory KanbanRun.fromJson(Map<String, dynamic> json) => KanbanRun(
    id: _int(json['id']),
    status: json['status'] as String? ?? '',
    profile: _text(json['profile']),
    outcome: _text(json['outcome']),
    summary: _text(json['summary']),
    error: _text(json['error']),
    startedAt: _time(json['started_at']),
    endedAt: _time(json['ended_at']),
  );

  final int id;
  final String status;
  final String? profile;
  final String? outcome;
  final String? summary;
  final String? error;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Still in flight, so it can be terminated. A run that never got an end
  /// time but is not marked running (a crashed worker) is not.
  bool get active => endedAt == null && status == 'running';
}

class KanbanAttachment {
  const KanbanAttachment({
    required this.id,
    required this.filename,
    this.size = 0,
  });

  factory KanbanAttachment.fromJson(Map<String, dynamic> json) =>
      KanbanAttachment(
        id: _int(json['id']),
        filename: json['filename'] as String? ?? '',
        size: _int(json['size']),
      );

  final int id;
  final String filename;
  final int size;
}

/// A distress signal the plugin raised on a task (stale worker, repeated
/// failures, and so on).
class KanbanDiagnostic {
  const KanbanDiagnostic({
    required this.title,
    required this.severity,
    this.detail = '',
  });

  factory KanbanDiagnostic.fromJson(Map<String, dynamic> json) =>
      KanbanDiagnostic(
        title: json['title'] as String? ?? json['kind'] as String? ?? '',
        severity: json['severity'] as String? ?? 'warning',
        detail: json['detail'] as String? ?? '',
      );

  final String title;
  final String severity;
  final String detail;
}

/// The tail of a worker's stdout and stderr.
class KanbanTaskLog {
  const KanbanTaskLog({
    required this.content,
    this.exists = false,
    this.truncated = false,
  });

  factory KanbanTaskLog.fromJson(Map<String, dynamic> json) => KanbanTaskLog(
    content: json['content'] as String? ?? '',
    exists: json['exists'] == true,
    truncated: json['truncated'] == true,
  );

  final String content;
  final bool exists;
  final bool truncated;
}

/// `GET /tasks/{id}`: a task with everything the detail view shows.
class KanbanTaskDetail {
  const KanbanTaskDetail({
    required this.task,
    this.comments = const [],
    this.events = const [],
    this.parents = const [],
    this.children = const [],
    this.childResults = const [],
    this.runs = const [],
    this.attachments = const [],
    this.diagnostics = const [],
  });

  factory KanbanTaskDetail.fromJson(Map<String, dynamic> json) {
    List<T> all<T>(Object? v, T Function(Map<String, dynamic>) read) => [
      if (v is List)
        for (final e in v)
          if (e is Map<String, dynamic>) read(e),
    ];
    List<String> ids(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is String) e,
    ];
    final links = json['links'];
    return KanbanTaskDetail(
      task: KanbanTask.fromJson(
        json['task'] is Map<String, dynamic>
            ? json['task'] as Map<String, dynamic>
            : const {},
      ),
      comments: all(json['comments'], KanbanComment.fromJson),
      events: all(json['events'], KanbanEvent.fromJson),
      parents: links is Map ? ids(links['parents']) : const [],
      children: links is Map ? ids(links['children']) : const [],
      childResults: all(json['child_results'], KanbanChildResult.fromJson),
      runs: all(json['runs'], KanbanRun.fromJson),
      attachments: all(json['attachments'], KanbanAttachment.fromJson),
      diagnostics: all(
        (json['task'] as Map?)?['diagnostics'],
        KanbanDiagnostic.fromJson,
      ),
    );
  }

  final KanbanTask task;
  final List<KanbanComment> comments;
  final List<KanbanEvent> events;
  final List<String> parents;
  final List<String> children;
  final List<KanbanChildResult> childResults;
  final List<KanbanRun> runs;
  final List<KanbanAttachment> attachments;
  final List<KanbanDiagnostic> diagnostics;
}

/// What the triage helpers report: they run an LLM, and a refusal is an
/// answer, not an HTTP error.
class KanbanTriageOutcome {
  const KanbanTriageOutcome({
    required this.ok,
    this.reason,
    this.childIds = const [],
  });

  factory KanbanTriageOutcome.fromJson(Map<String, dynamic> json) =>
      KanbanTriageOutcome(
        ok: json['ok'] == true,
        reason: _text(json['reason']),
        childIds: [
          if (json['child_ids'] is List)
            for (final id in json['child_ids'] as List)
              if (id is String) id,
        ],
      );

  final bool ok;
  final String? reason;
  final List<String> childIds;
}

/// A task a bulk change could not apply to, and why.
class KanbanBulkFailure {
  const KanbanBulkFailure({required this.id, required this.error});

  final String id;
  final String error;
}

/// The `kanban.*` knobs that steer how tasks are fanned out and picked up.
class KanbanOrchestration {
  const KanbanOrchestration({
    this.orchestratorProfile = '',
    this.defaultAssignee = '',
    this.autoDecompose = true,
    this.autoPromoteChildren = true,
    this.activeProfile = 'default',
  });

  factory KanbanOrchestration.fromJson(Map<String, dynamic> json) =>
      KanbanOrchestration(
        orchestratorProfile: json['orchestrator_profile'] as String? ?? '',
        defaultAssignee: json['default_assignee'] as String? ?? '',
        autoDecompose: json['auto_decompose'] != false,
        autoPromoteChildren: json['auto_promote_children'] != false,
        activeProfile: json['active_profile'] as String? ?? 'default',
      );

  /// Empty means "use the active profile".
  final String orchestratorProfile;
  final String defaultAssignee;
  final bool autoDecompose;
  final bool autoPromoteChildren;
  final String activeProfile;
}

/// A rough size for a task, from the plugin's language-model helper. Not a
/// cost in money: a token count and a small/medium/large read.
class KanbanEstimate {
  const KanbanEstimate({
    required this.ok,
    this.tokens,
    this.complexity,
    this.rationale,
    this.reason,
  });

  factory KanbanEstimate.fromJson(Map<String, dynamic> json) => KanbanEstimate(
    ok: json['ok'] == true,
    tokens: json['est_tokens'] is num
        ? (json['est_tokens'] as num).toInt()
        : null,
    complexity: _text(json['complexity']),
    rationale: _text(json['rationale']),
    reason: _text(json['reason']),
  );

  /// False when the helper could not answer (no model configured, a provider
  /// error); [reason] then says why. That is an answer, not an HTTP error.
  final bool ok;
  final int? tokens;
  final String? complexity;
  final String? rationale;
  final String? reason;

  /// `about 12k tokens · medium`, or the reason when there is no estimate.
  String get summary {
    if (!ok) return reason ?? 'No estimate available.';
    final size = tokens == null
        ? null
        : tokens! >= 1000
        ? 'about ${(tokens! / 1000).round()}k tokens'
        : 'about $tokens tokens';
    final read = switch (complexity?.toUpperCase()) {
      'S' => 'small',
      'M' => 'medium',
      'L' => 'large',
      final other => other,
    };
    final text = [?size, ?read].join(' · ');
    return text.isEmpty ? 'No estimate available.' : text;
  }
}

/// A messenger's home channel a task can post updates to.
class KanbanHomeChannel {
  const KanbanHomeChannel({
    required this.platform,
    required this.name,
    this.subscribed = false,
  });

  factory KanbanHomeChannel.fromJson(Map<String, dynamic> json) =>
      KanbanHomeChannel(
        platform: json['platform'] is String ? json['platform'] as String : '',
        name:
            _text(json['name']) ??
            (json['platform'] is String ? json['platform'] as String : ''),
        subscribed: json['subscribed'] == true,
      );

  final String platform;
  final String name;
  final bool subscribed;

  KanbanHomeChannel withSubscribed(bool value) =>
      KanbanHomeChannel(platform: platform, name: name, subscribed: value);
}

/// A worker process the dispatcher has running a task right now.
class KanbanWorker {
  const KanbanWorker({
    required this.runId,
    required this.taskId,
    required this.taskTitle,
    this.profile,
    this.pid,
    this.startedAt,
    this.lastHeartbeatAt,
  });

  factory KanbanWorker.fromJson(Map<String, dynamic> json) => KanbanWorker(
    runId: _int(json['run_id']),
    taskId: json['task_id'] as String? ?? '',
    taskTitle: json['task_title'] as String? ?? '',
    profile: _text(json['profile']) ?? _text(json['task_assignee']),
    pid: json['worker_pid'] is num ? (json['worker_pid'] as num).toInt() : null,
    startedAt: _time(json['started_at']),
    lastHeartbeatAt: _time(json['last_heartbeat_at']),
  );

  final int runId;
  final String taskId;
  final String taskTitle;
  final String? profile;
  final int? pid;
  final DateTime? startedAt;
  final DateTime? lastHeartbeatAt;
}

/// Live figures for a worker's process, when the server can read them.
class KanbanRunInspection {
  const KanbanRunInspection({
    required this.alive,
    this.pid,
    this.cpuPercent,
    this.memoryBytes,
    this.threads,
    this.status,
    this.note,
  });

  factory KanbanRunInspection.fromJson(Map<String, dynamic> json) =>
      KanbanRunInspection(
        alive: json['alive'] == true,
        pid: json['pid'] is num ? (json['pid'] as num).toInt() : null,
        cpuPercent: json['cpu_percent'] is num
            ? (json['cpu_percent'] as num).toDouble()
            : null,
        memoryBytes: json['memory_rss_bytes'] is num
            ? (json['memory_rss_bytes'] as num).toInt()
            : null,
        threads: json['num_threads'] is num
            ? (json['num_threads'] as num).toInt()
            : null,
        status: _text(json['status']),
        note: _text(json['reason']) ?? _text(json['error']),
      );

  /// False when the process is gone or cannot be read; [note] says which.
  final bool alive;
  final int? pid;
  final double? cpuPercent;
  final int? memoryBytes;
  final int? threads;
  final String? status;
  final String? note;
}

/// The archive a board export wrote, on the server.
class KanbanExport {
  const KanbanExport({required this.archive, this.size = 0});

  factory KanbanExport.fromJson(Map<String, dynamic> json) => KanbanExport(
    archive: json['archive'] as String? ?? '',
    size: _int(json['size']),
  );

  /// A path on the server's filesystem, not on this device.
  final String archive;
  final int size;
}

/// The board an import created; its slug may differ from the one asked for.
class KanbanImport {
  const KanbanImport({required this.board, this.renamed = false});

  factory KanbanImport.fromJson(Map<String, dynamic> json) => KanbanImport(
    board: json['board'] as String? ?? '',
    renamed: json['renamed'] == true,
  );

  final String board;
  final bool renamed;
}
