import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import 'catalog_entry.dart';
import 'installed_plugin.dart';
import 'plugin_install_result.dart';

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

  /// Throws [PluginsUnsupported] on a server without the route.
  Future<List<CatalogEntry>> loadCatalog() async {
    final Response<Object> response;
    try {
      response = await _api.getPluginsCatalogApiDashboardPluginsCatalogGet();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const PluginsUnsupported();
      rethrow;
    }
    final rows = switch (response.data) {
      {'entries': final List<dynamic> rows} => rows,
      _ => const <dynamic>[],
    };
    return [
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row case {'name': final String name} when name.isNotEmpty)
          CatalogEntry(
            name: name,
            description: _text(row['description']) ?? '',
            maintainer: _text(row['maintainer']) ?? '',
            tier: row['tier'] == 'official'
                ? CatalogTier.official
                : CatalogTier.community,
            requiresHermes: _text(row['requires_hermes']) ?? '',
            platforms: _strings(row['platforms']),
            docsUrl: _text(row['docs_url']) ?? '',
            commit: _commit(row),
            providesTools: _strings(_capability(row, 'provides_tools')),
            providesHooks: _strings(_capability(row, 'provides_hooks')),
            providesMiddleware: _strings(
              _capability(row, 'provides_middleware'),
            ),
            requiresEnv: _strings(_capability(row, 'requires_env')),
            installed: row['installed'] == true,
            updateAvailable: row['update_available'] == true,
          ),
    ];
  }

  /// Installs the catalog entry [name]. The server resolves its repository
  /// and pinned commit, so only the name is sent.
  Future<PluginInstallResult> installFromCatalog(
    String name, {
    bool enable = true,
  }) => _install(
    AgentPluginInstallBody(identifier: '', catalogName: name, enable: enable),
  );

  /// Installs from a Git URL or `owner/repo`: code the catalog has not
  /// reviewed.
  Future<PluginInstallResult> installFromSource(
    String identifier, {
    bool enable = true,
    bool force = false,
  }) => _install(
    AgentPluginInstallBody(
      identifier: identifier,
      enable: enable,
      force: force,
    ),
  );

  /// Never throws. A timeout is reported as such: cloning and scanning can
  /// take longer than the client waits.
  Future<PluginInstallResult> _install(AgentPluginInstallBody body) async {
    try {
      final response = await _api
          .postAgentPluginInstallApiDashboardAgentPluginsInstallPost(
            agentPluginInstallBody: body,
          );
      final data = response.data is Map ? response.data! as Map : const {};
      return PluginInstallResult(
        ok: true,
        pluginName: _text(data['plugin_name']) ?? '',
        warnings: _strings(data['warnings']),
        missingEnv: _strings(data['missing_env']),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const PluginInstallResult(ok: false, timedOut: true);
      }
      return PluginInstallResult(ok: false, message: _reason(e));
    } on Object {
      return const PluginInstallResult(ok: false);
    }
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
      return PluginActionResult(ok: false, message: _reason(e));
    } on Object {
      return const PluginActionResult(ok: false);
    }
  }

  /// The server's own reason for a refusal (a 4xx with a `detail` string).
  static String? _reason(DioException e) {
    final status = e.response?.statusCode ?? 0;
    if (status < 400 || status >= 500) return null;
    return switch (e.response?.data) {
      {'detail': final String detail} when detail.isNotEmpty => detail,
      _ => null,
    };
  }

  static Object? _capability(Map<String, dynamic> row, String key) =>
      row['capabilities'] is Map ? (row['capabilities'] as Map)[key] : null;

  static List<String> _strings(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is String && item.isNotEmpty) item,
  ];

  static String _commit(Map<String, dynamic> row) {
    final short = _text(row['sha_short']);
    if (short != null) return short;
    final sha = _text(row['sha']);
    return sha == null ? '' : sha.substring(0, sha.length < 7 ? sha.length : 7);
  }

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static PluginStatus _status(Object? value) => switch (value) {
    'enabled' => PluginStatus.enabled,
    'disabled' => PluginStatus.disabled,
    _ => PluginStatus.inactive,
  };
}
