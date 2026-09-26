import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import '../api/hermes_api_client.dart';
import '../models/model_provider_option.dart';
import 'kanban_models.dart';

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
    var data = e.response?.data;
    // A download asks for raw bytes, so its error body arrives as bytes too.
    if (data is List<int>) {
      try {
        data = jsonDecode(utf8.decode(data));
      } on FormatException {
        // Not JSON (a proxy's error page): there is no reason to read.
      }
    }
    final detail = data is Map ? data['detail'] : null;
    if (detail is String) throw KanbanException(detail);
    // A request the plugin could not validate lists what was wrong.
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      final message = (detail.first as Map)['msg'];
      if (message is String) throw KanbanException(message);
    }
    rethrow;
  }
}

/// Reads and changes the Kanban plugin's boards through the generated
/// [DefaultApi].
///
/// The plugin's routes declare no response schema, so bodies are parsed by
/// hand into the models in `kanban_models.dart`.
class KanbanRepository {
  /// Takes the whole client, not only its generated half: attachment downloads
  /// are fetched through [HermesApiClient.fetchKanbanAttachment], since the
  /// generated client cannot return a file's bytes.
  KanbanRepository(this.client) : _api = client.raw;

  final DefaultApi _api;
  final HermesApiClient client;

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

  /// The models a task can be pinned to. Like the dashboard, a failed request
  /// reads as no options, which leaves a free-text model name.
  Future<ModelOptions> loadModelOptions() async {
    try {
      final response = await _api.modelOptionsApiPluginsKanbanModelOptionsGet();
      return ModelOptions.fromJson(response.data);
    } on DioException {
      return const ModelOptions();
    }
  }

  /// Creates a task and returns the dispatcher warning the plugin attaches
  /// when a ready, assigned task would sit idle (null otherwise). [model]
  /// pins the task to a listed model and effort; [modelName] is a model typed
  /// by hand when the plugin lists none. Without either the assignee's
  /// profile decides.
  Future<String?> createTask({
    required String title,
    String? body,
    String? assignee,
    String? tenant,
    int priority = 0,
    bool triage = false,
    List<String> parents = const [],
    ModelChoice? model,
    String? modelName,
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
        modelOverride: model?.modelId ?? modelName,
        providerOverride: model?.providerId,
        reasoningEffort: model?.effort,
      ),
      board: board,
    );
    return _map(response.data)['warning'] as String?;
  });

  /// Changes a task. Fields left null are not sent. `status` must be one of
  /// [kanbanSettableStatuses]; the plugin refuses `running`. [model] and
  /// [modelName] set the model override as in [createTask]; the model and the
  /// effort are cleared separately with [clearModel] and [clearEffort].
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
    ModelChoice? model,
    String? modelName,
    bool clearModel = false,
    bool clearEffort = false,
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
        modelOverride: model?.modelId ?? modelName,
        providerOverride: model?.providerId,
        reasoningEffort: model?.effort,
        clearModelOverride: clearModel,
        clearReasoningEffort: clearEffort,
      ),
      board: board,
    ),
  );

  /// Archives a task; the plugin's refusal for it is raised as a
  /// [KanbanException] rather than read as success.
  Future<void> archiveTask(String id, {String? board}) async {
    final failures = await bulkUpdate([id], archive: true, board: board);
    if (failures.isNotEmpty) throw KanbanException(failures.first.error);
  }

  /// Fans a triage task out into a set of tasks with the plugin's LLM helper.
  Future<KanbanTriageOutcome> decomposeTask(String id, {String? board}) =>
      _guard(() async {
        final response = await _api
            .decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost(
              taskId: id,
              decomposeBody: DecomposeBody(),
              board: board,
            );
        return KanbanTriageOutcome.fromJson(_map(response.data));
      });

  /// Expands a one-line triage task into a spec and promotes it to todo.
  Future<KanbanTriageOutcome> specifyTask(String id, {String? board}) =>
      _guard(() async {
        final response = await _api
            .specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost(
              taskId: id,
              specifyBody: SpecifyBody(),
              board: board,
            );
        return KanbanTriageOutcome.fromJson(_map(response.data));
      });

  /// Releases a running task's worker claim without waiting for it to expire.
  Future<void> reclaimTask(String id, {String? reason, String? board}) =>
      _guard(
        () => _api.reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost(
          taskId: id,
          reclaimBody: ReclaimBody(reason: reason),
          board: board,
        ),
      );

  /// Applies one change to many tasks; the ones it could not apply to come
  /// back, the rest went through.
  Future<List<KanbanBulkFailure>> bulkUpdate(
    List<String> ids, {
    String? status,
    String? assignee,
    int? priority,
    String? effort,
    bool clearEffort = false,
    bool archive = false,
    String? board,
  }) => _guard(() async {
    final response = await _api.bulkUpdateApiPluginsKanbanTasksBulkPost(
      bulkTaskBody: BulkTaskBody(
        ids: ids.toList(),
        status: status,
        assignee: assignee,
        priority: priority,
        reasoningEffort: effort,
        clearReasoningEffort: clearEffort,
        archive: archive,
      ),
      board: board,
    );
    final results = _map(response.data)['results'];
    return [
      if (results is List)
        for (final r in results)
          if (r is Map && r['ok'] == false)
            KanbanBulkFailure(
              id: r['id'] as String? ?? '',
              error: r['error'] as String? ?? 'failed',
            ),
    ];
  });

  /// Runs the dispatcher now instead of waiting for its next tick.
  Future<void> dispatch({String? board}) =>
      _guard(() => _api.dispatchApiPluginsKanbanDispatchPost(board: board));

  Future<KanbanOrchestration> loadOrchestration() async {
    final response = await _api
        .getOrchestrationSettingsApiPluginsKanbanOrchestrationGet();
    return KanbanOrchestration.fromJson(_map(response.data));
  }

  Future<KanbanOrchestration> saveOrchestration({
    String? orchestratorProfile,
    String? defaultAssignee,
    bool? autoDecompose,
    bool? autoPromoteChildren,
  }) => _guard(() async {
    final response = await _api
        .setOrchestrationSettingsApiPluginsKanbanOrchestrationPut(
          orchestrationSettingsBody: OrchestrationSettingsBody(
            orchestratorProfile: orchestratorProfile,
            defaultAssignee: defaultAssignee,
            autoDecompose: autoDecompose,
            autoPromoteChildren: autoPromoteChildren,
          ),
        );
    return KanbanOrchestration.fromJson(_map(response.data));
  });

  /// The end of the worker's log for a task, at most [tail] bytes.
  Future<KanbanTaskLog> loadTaskLog(
    String id, {
    int tail = 20000,
    String? board,
  }) => _guard(() async {
    final response = await _api.getTaskLogApiPluginsKanbanTasksTaskIdLogGet(
      taskId: id,
      tail: tail,
      board: board,
    );
    return KanbanTaskLog.fromJson(_map(response.data));
  });

  /// Stops an in-flight run; the plugin refuses when it already ended.
  Future<void> terminateRun(int runId, {String? reason, String? board}) =>
      _guard(
        () => _api.terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost(
          runId: runId,
          terminateRunBody: TerminateRunBody(reason: reason),
          board: board,
        ),
      );

  /// Attaches [bytes] to a task as [filename]. The plugin caps the size and
  /// refuses with a reason, which is raised as a [KanbanException].
  Future<void> uploadAttachment(
    String taskId,
    String filename,
    Uint8List bytes, {
    String? board,
  }) => _guard(
    () => _api.uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost(
      taskId: taskId,
      file: MultipartFile.fromBytes(bytes, filename: filename),
      board: board,
    ),
  );

  Future<Uint8List> downloadAttachment(int id, {String? board}) =>
      _guard(() => client.fetchKanbanAttachment(id, board: board));

  /// Sizes up an existing task.
  Future<KanbanEstimate> estimateTask(String id, {String? board}) =>
      _guard(() async {
        final response = await _api
            .estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost(
              taskId: id,
              board: board,
            );
        return KanbanEstimate.fromJson(_map(response.data));
      });

  /// Sizes up a task that does not exist yet, from its title and description.
  Future<KanbanEstimate> estimateText(String title, {String? body}) =>
      _guard(() async {
        final response = await _api
            .estimateTextEndpointApiPluginsKanbanEstimatePost(
              estimateBody: EstimateBody(title: title, body: body),
            );
        return KanbanEstimate.fromJson(_map(response.data));
      });

  /// The messengers with a home channel, and whether [taskId] posts to each.
  Future<List<KanbanHomeChannel>> loadHomeChannels(
    String taskId, {
    String? board,
  }) async {
    final response = await _api.getHomeChannelsApiPluginsKanbanHomeChannelsGet(
      taskId: taskId,
      board: board,
    );
    final channels = _map(response.data)['home_channels'];
    return [
      if (channels is List)
        for (final c in channels)
          if (c is Map<String, dynamic>)
            if (KanbanHomeChannel.fromJson(c) case final channel
                when channel.platform.isNotEmpty)
              channel,
    ];
  }

  Future<void> setHomeSubscription(
    String taskId,
    String platform, {
    required bool subscribed,
    String? board,
  }) => _guard(
    () => subscribed
        ? _api.subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost(
            taskId: taskId,
            platform: platform,
            board: board,
          )
        : _api.unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete(
            taskId: taskId,
            platform: platform,
            board: board,
          ),
  );

  /// Every worker the dispatcher has running a task.
  Future<List<KanbanWorker>> loadActiveWorkers({String? board}) =>
      _guard(() async {
        final response = await _api
            .listActiveWorkersApiPluginsKanbanWorkersActiveGet(board: board);
        final workers = _map(response.data)['workers'];
        return [
          if (workers is List)
            for (final w in workers)
              if (w is Map<String, dynamic>) KanbanWorker.fromJson(w),
        ];
      });

  /// Live figures for a run's worker process. The plugin reads CPU from a
  /// fresh process handle, so its first reading is always 0; the app shows
  /// memory and threads instead.
  Future<KanbanRunInspection> inspectRun(int runId, {String? board}) =>
      _guard(() async {
        final response = await _api
            .inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet(
              runId: runId,
              board: board,
            );
        return KanbanRunInspection.fromJson(_map(response.data));
      });

  /// Writes a board to an archive on the *server* ([output] is a server path;
  /// empty lets the server choose its export folder).
  Future<KanbanExport> exportBoard(
    String slug, {
    String output = '',
    bool attachments = true,
    bool logs = false,
  }) => _guard(() async {
    final response = await _api
        .exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost(
          slug: slug,
          exportBoardBody: ExportBoardBody(
            output: output,
            attachments: attachments,
            logs: logs,
          ),
        );
    return KanbanExport.fromJson(_map(response.data));
  });

  /// Creates a new board from an archive already on the *server*.
  Future<KanbanImport> importBoard(
    String archive, {
    String? slug,
    bool switchToIt = false,
  }) => _guard(() async {
    final response = await _api
        .importBoardEndpointApiPluginsKanbanBoardsImportPost(
          importBoardBody: ImportBoardBody(
            archive: archive,
            slug: slug,
            switch_: switchToIt,
          ),
        );
    return KanbanImport.fromJson(_map(response.data));
  });

  Future<void> removeAttachment(int id, {String? board}) => _guard(
    () => _api.removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete(
      attachmentId: id,
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

  Future<void> createBoard({
    required String slug,
    String? name,
    String? description,
  }) => _guard(
    () => _api.createBoardEndpointApiPluginsKanbanBoardsPost(
      createBoardBody: CreateBoardBody(
        slug: slug,
        name: name,
        description: description,
      ),
    ),
  );

  Future<void> renameBoard(String slug, {String? name, String? description}) =>
      _guard(
        () => _api.renameBoardApiPluginsKanbanBoardsSlugPatch(
          slug: slug,
          renameBoardBody: RenameBoardBody(
            name: name,
            description: description,
          ),
        ),
      );

  /// Archives a board, or with [hardDelete] removes it for good.
  Future<void> removeBoard(String slug, {bool hardDelete = false}) => _guard(
    () => _api.deleteBoardApiPluginsKanbanBoardsSlugDelete(
      slug: slug,
      delete: hardDelete,
    ),
  );

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
