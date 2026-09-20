import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import 'kanban_models.dart';

/// Reads the Kanban plugin's boards through the generated [DefaultApi].
///
/// The plugin's routes declare no response schema, so bodies are parsed by
/// hand into the models in `kanban_models.dart`.
/// The plugin refused a request and said why (`{"detail": "..."}`), for
/// example a task that cannot move to `ready` while a parent is open.
class KanbanException implements Exception {
  const KanbanException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<T> _guard<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is String) throw KanbanException(detail);
    rethrow;
  }
}

class KanbanRepository {
  KanbanRepository(this._api);

  final DefaultApi _api;

  Future<KanbanBoard> loadBoard({
    String? board,
    String? tenant,
    bool includeArchived = false,
  }) async {
    final response = await _api.getBoardEndpointApiPluginsKanbanBoardGet(
      board: board,
      tenant: tenant,
      includeArchived: includeArchived,
    );
    return KanbanBoard.fromJson(_map(response.data));
  }

  Future<KanbanTaskDetail> loadTask(String id, {String? board}) =>
      _guard(() async {
        final response = await _api.getTaskApiPluginsKanbanTasksTaskIdGet(
          taskId: id,
          board: board,
        );
        return KanbanTaskDetail.fromJson(_map(response.data));
      });

  /// Creates a task and returns the dispatcher warning the plugin attaches
  /// when a ready, assigned task would sit idle (null otherwise).
  Future<String?> createTask({
    required String title,
    String? body,
    String? assignee,
    String? tenant,
    int priority = 0,
    bool triage = false,
    List<String> parents = const [],
    String? board,
  }) => _guard(() async {
    final response = await _api.createTaskApiPluginsKanbanTasksPost(
      createTaskBody: CreateTaskBody(
        title: title,
        body: body,
        assignee: assignee,
        tenant: tenant,
        priority: priority,
        triage: triage,
        parents: parents.toList(),
      ),
      board: board,
    );
    return _map(response.data)['warning'] as String?;
  });

  /// Changes a task. Fields left null are not sent. `status` must be one of
  /// [kanbanSettableStatuses]; the plugin refuses `running`.
  Future<void> updateTask(
    String id, {
    String? status,
    String? assignee,
    int? priority,
    String? title,
    String? body,
    String? result,
    String? summary,
    String? blockReason,
    String? board,
  }) => _guard(
    () => _api.updateTaskApiPluginsKanbanTasksTaskIdPatch(
      taskId: id,
      updateTaskBody: UpdateTaskBody(
        status: status,
        assignee: assignee,
        priority: priority,
        title: title,
        body: body,
        result: result,
        summary: summary,
        blockReason: blockReason,
      ),
      board: board,
    ),
  );

  Future<void> archiveTask(String id, {String? board}) => _guard(
    () => _api.bulkUpdateApiPluginsKanbanTasksBulkPost(
      bulkTaskBody: BulkTaskBody(ids: [id], archive: true),
      board: board,
    ),
  );

  Future<void> deleteTask(String id, {String? board}) => _guard(
    () => _api.deleteTaskApiPluginsKanbanTasksTaskIdDelete(
      taskId: id,
      board: board,
    ),
  );

  Future<void> addComment(String id, String body, {String? board}) => _guard(
    () => _api.addCommentApiPluginsKanbanTasksTaskIdCommentsPost(
      taskId: id,
      commentBody: CommentBody(body: body),
      board: board,
    ),
  );

  Future<void> addLink(String parent, String child, {String? board}) => _guard(
    () => _api.addLinkApiPluginsKanbanLinksPost(
      linkBody: LinkBody(parentId: parent, childId: child),
      board: board,
    ),
  );

  Future<void> removeLink(String parent, String child, {String? board}) =>
      _guard(
        () => _api.deleteLinkApiPluginsKanbanLinksDelete(
          parentId: parent,
          childId: child,
          board: board,
        ),
      );

  /// Every profile and assignee the board knows, for the assignee picker.
  Future<List<String>> loadAssignees({String? board}) async {
    final response = await _api.getAssigneesApiPluginsKanbanAssigneesGet(
      board: board,
    );
    final names = _map(response.data)['assignees'];
    return [
      if (names is List)
        for (final n in names)
          if (n is String) n,
    ];
  }

  Future<List<KanbanBoardInfo>> listBoards() async {
    final response = await _api.listBoardsApiPluginsKanbanBoardsGet();
    final boards = _map(response.data)['boards'];
    return [
      if (boards is List)
        for (final b in boards)
          if (b is Map<String, dynamic>) KanbanBoardInfo.fromJson(b),
    ];
  }
}

Map<String, dynamic> _map(Object? data) =>
    data is Map<String, dynamic> ? data : const {};

/// The statuses a person may set from the app; `running` belongs to the
/// dispatcher and `archived` has its own action.
const kanbanSettableStatuses = [
  'triage',
  'todo',
  'scheduled',
  'ready',
  'blocked',
  'review',
  'done',
];
