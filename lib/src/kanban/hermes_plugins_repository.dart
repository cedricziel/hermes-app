import 'package:hermes_api/hermes_api.dart';

/// Asks the dashboard which of its optional plugins are switched on.
///
/// `GET /api/dashboard/plugins` only lists plugins that are enabled and not
/// hidden, so a plugin's presence in the list is the whole answer. The route
/// declares no response schema, so the list is read by hand.
class HermesPluginsRepository {
  HermesPluginsRepository(this._api);

  final DefaultApi _api;

  /// Whether the bundled Kanban plugin is on. Any failure, including a server
  /// too old to have the route, reads as off: the app never offers a feature
  /// it cannot confirm.
  Future<bool> isKanbanEnabled() async {
    try {
      final response = await _api.getDashboardPluginsApiDashboardPluginsGet();
      final data = response.data;
      if (data is! List) return false;
      return data.any((p) => p is Map && p['name'] == kanbanPluginName);
    } on Object catch (_) {
      return false;
    }
  }
}

const kanbanPluginName = 'kanban';
