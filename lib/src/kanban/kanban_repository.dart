import 'package:hermes_api/hermes_api.dart';

import 'kanban_models.dart';

/// Reads the Kanban plugin's boards through the generated [DefaultApi].
///
/// The plugin's routes declare no response schema, so bodies are parsed by
/// hand into the models in `kanban_models.dart`.
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
