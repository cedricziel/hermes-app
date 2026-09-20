import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import 'installed_plugin.dart';

/// The server has no plugin hub: it is older than the app needs.
class PluginsUnsupported implements Exception {
  const PluginsUnsupported();
}

/// Reads and changes the plugins of the dashboard through the generated
/// [DefaultApi].
///
/// None of the routes declares a response schema, so the hub is parsed by
/// hand, skipping rows that don't fit. The generated client puts a plugin's
/// name into the path as it is, so names are encoded here.
class HermesPluginManagerRepository {
  HermesPluginManagerRepository(this._api);

  final DefaultApi _api;

  /// Throws [PluginsUnsupported] on a server without the route.
  Future<List<InstalledPlugin>> load() async {
    final Response<Object> response;
    try {
      response = await _api.getPluginsHubApiDashboardPluginsHubGet();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const PluginsUnsupported();
      rethrow;
    }
    final rows = switch (response.data) {
      {'plugins': final List<dynamic> rows} => rows,
      _ => const <dynamic>[],
    };
    return [
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row case {'name': final String name} when name.isNotEmpty)
          InstalledPlugin(
            name: name,
            version: _text(row['version']) ?? '',
            description: _text(row['description']) ?? '',
            source: _text(row['source']) ?? '',
            status: _status(row['runtime_status']),
            canRemove: row['can_remove'] == true,
            canUpdate: row['can_update_git'] == true,
            authRequired: row['auth_required'] == true,
            authCommand: _text(row['auth_command']),
            hidden: row['user_hidden'] == true,
            removedReason: _text(row['removed_reason']),
          ),
    ];
  }

  Future<PluginActionResult> setEnabled(String name, bool enabled) => _act(
    () => enabled
        ? _api.postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost(
            name: Uri.encodeComponent(name),
          )
        : _api.postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost(
            name: Uri.encodeComponent(name),
          ),
  );

  Future<PluginActionResult> update(String name) => _act(
    () => _api.postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost(
      name: Uri.encodeComponent(name),
    ),
  );

  Future<PluginActionResult> remove(String name) => _act(
    () => _api.deleteAgentPluginApiDashboardAgentPluginsNameDelete(
      name: Uri.encodeComponent(name),
    ),
  );

  Future<PluginActionResult> setHidden(String name, bool hidden) => _act(
    () => _api.postPluginVisibilityApiDashboardPluginsNameVisibilityPost(
      name: Uri.encodeComponent(name),
      pluginVisibilityBody: PluginVisibilityBody(hidden: hidden),
    ),
  );

  /// Never throws: a refusal carries the server's own reason when it gave a
  /// usable one, any other failure carries none.
  Future<PluginActionResult> _act(
    Future<Response<Object>> Function() call,
  ) async {
    try {
      final response = await call();
      final unchanged = switch (response.data) {
        {'unchanged': true} => true,
        _ => false,
      };
      return PluginActionResult(ok: true, unchanged: unchanged);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final detail = switch (e.response?.data) {
        {'detail': final String detail} when detail.isNotEmpty => detail,
        _ => null,
      };
      return PluginActionResult(
        ok: false,
        message: status >= 400 && status < 500 ? detail : null,
      );
    } on Object {
      return const PluginActionResult(ok: false);
    }
  }

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static PluginStatus _status(Object? value) => switch (value) {
    'enabled' => PluginStatus.enabled,
    'disabled' => PluginStatus.disabled,
    _ => PluginStatus.inactive,
  };
}
