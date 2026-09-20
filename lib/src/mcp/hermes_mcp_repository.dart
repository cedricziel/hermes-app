import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

enum McpTransport { remote, command, unknown }

/// One entry of a profile's `mcp_servers`, as the dashboard summarises it.
///
/// The dashboard redacts environment values and this class does not keep them
/// at all. It also does not say whether the server works: that is only known
/// after a test.
class HermesMcpServer {
  const HermesMcpServer({
    required this.name,
    required this.transport,
    this.url,
    this.command,
    this.args = const [],
    this.auth,
    this.enabled = true,
  });

  final String name;
  final McpTransport transport;
  final String? url;
  final String? command;
  final List<String> args;

  /// How the server signs in: `oauth`, `header`, another value Hermes
  /// reports, or null.
  final String? auth;
  final bool enabled;

  bool get usesOAuth => auth == 'oauth';

  /// The URL of a remote server, otherwise the command with its arguments.
  String get address => switch (transport) {
    McpTransport.remote => url ?? '',
    _ => [?command, ...args].join(' '),
  };

  HermesMcpServer withEnabled(bool enabled) => HermesMcpServer(
    name: name,
    transport: transport,
    url: url,
    command: command,
    args: args,
    auth: auth,
    enabled: enabled,
  );
}

class HermesMcpTool {
  const HermesMcpTool({
    required this.name,
    this.description = '',
    this.schemaChars,
  });

  final String name;
  final String description;

  /// What the tool's schema costs the model, when the dashboard says.
  final int? schemaChars;
}

/// The answer to a connection test. A failed probe is an answer, not an
/// exception: the dashboard replies 200 with `ok: false`.
class HermesMcpTestResult {
  const HermesMcpTestResult({
    required this.ok,
    this.error = '',
    this.tools = const [],
    this.prompts = 0,
    this.resources = 0,
    this.signInNeeded = false,
  });

  final bool ok;
  final String error;
  final List<HermesMcpTool> tools;
  final int prompts;
  final int resources;

  /// The server signs in with OAuth and Hermes holds no token for it yet.
  final bool signInNeeded;
}

/// How a catalog entry authenticates: `api_key` (credentials in the profile's
/// `.env`), `oauth` (a sign-in on the server) or `none`.
enum McpAuthKind { apiKey, oauth, none, unknown }

/// A credential a catalog entry declares. Hermes sends its name and prompt,
/// never a value.
class HermesMcpCredential {
  const HermesMcpCredential({
    required this.name,
    required this.prompt,
    this.required = true,
  });

  final String name;
  final String prompt;
  final bool required;
}

/// One approved server of Hermes' catalog, annotated with whether the
/// profile has it. The transport, command and build steps are kept because
/// the catalog's trust model asks the user to see them before installing.
class HermesMcpCatalogEntry {
  const HermesMcpCatalogEntry({
    required this.name,
    required this.transport,
    this.description = '',
    this.source = '',
    this.authKind = McpAuthKind.none,
    this.requiredEnv = const [],
    this.command,
    this.args = const [],
    this.url,
    this.installUrl,
    this.installRef,
    this.bootstrap = const [],
    this.installed = false,
    this.enabled = false,
  });

  final String name;
  final McpTransport transport;
  final String description;
  final String source;
  final McpAuthKind authKind;
  final List<HermesMcpCredential> requiredEnv;
  final String? command;
  final List<String> args;
  final String? url;

  /// The repository Hermes clones and the reference it checks out, for an
  /// entry that has to be built on the server.
  final String? installUrl;
  final String? installRef;
  final List<String> bootstrap;
  final bool installed;
  final bool enabled;

  bool get buildsLocally => installUrl != null;

  /// Whether the entry names an address or a command, so the user can see
  /// what installing it would run.
  bool get hasTarget =>
      (url?.isNotEmpty ?? false) || (command?.isNotEmpty ?? false);

  HermesMcpCatalogEntry withInstalled({required bool enabled}) =>
      HermesMcpCatalogEntry(
        name: name,
        transport: transport,
        description: description,
        source: source,
        authKind: authKind,
        requiredEnv: requiredEnv,
        command: command,
        args: args,
        url: url,
        installUrl: installUrl,
        installRef: installRef,
        bootstrap: bootstrap,
        installed: true,
        enabled: enabled,
      );
}

class HermesMcpCatalog {
  const HermesMcpCatalog({required this.entries, this.hasDiagnostics = false});

  final List<HermesMcpCatalogEntry> entries;

  /// Hermes could not read some catalog files and says so.
  final bool hasDiagnostics;
}

class HermesMcpInstallResult {
  const HermesMcpInstallResult({required this.name, this.action});

  final String name;

  /// The background process building the entry on the server, or null when
  /// the install finished with the request.
  final String? action;
}

/// A background process on the server, as `GET /api/actions/{name}/status`
/// reports it.
class HermesMcpAction {
  const HermesMcpAction({
    required this.running,
    this.exitCode,
    this.lines = const [],
  });

  final bool running;
  final int? exitCode;

  /// The tail of its log.
  final List<String> lines;
}

enum McpFlowStatus { starting, authorizationRequired, approved, error, unknown }

/// A sign-in that Hermes runs on the server for an OAuth server. The user
/// approves it in a browser; Hermes receives the code and keeps the token.
class HermesMcpFlow {
  const HermesMcpFlow({
    required this.flowId,
    required this.status,
    this.authorizationUrl,
    this.error,
  });

  final String flowId;
  final McpFlowStatus status;
  final String? authorizationUrl;
  final String? error;
}

/// Hermes refused a request with a reason of its own: 400 for a bad request,
/// 409 or 429 when a sign-in for the server is already running or too many
/// are. [reason] is Hermes' text, empty when it sent none.
class McpRefused implements Exception {
  const McpRefused(this.status, this.reason);

  final int status;
  final String reason;

  /// Hermes joins the problems of a rejected replace with "; ".
  List<String> get problems => [
    for (final part in reason.split('; '))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  @override
  String toString() => 'McpRefused($status)';
}

/// How a remote server signs in when it is added.
enum McpRemoteAuth { none, bearerToken, oauth }

/// A server to add. Each shape can only carry what Hermes accepts for it: a
/// remote server takes no arguments or environment, a command server no
/// sign-in.
sealed class McpNewServer {
  const McpNewServer({required this.name});

  final String name;
}

class McpNewRemoteServer extends McpNewServer {
  const McpNewRemoteServer({
    required super.name,
    required this.url,
    this.auth = McpRemoteAuth.none,
    this.bearerToken,
  });

  final String url;
  final McpRemoteAuth auth;

  /// Sent only with [McpRemoteAuth.bearerToken]. Hermes keeps it in the
  /// profile's `.env` and never returns it.
  final String? bearerToken;
}

class McpNewCommandServer extends McpNewServer {
  const McpNewCommandServer({
    required super.name,
    required this.command,
    this.args = const [],
    this.env = const {},
  });

  final String command;
  final List<String> args;

  /// Environment values, which can be secrets.
  final Map<String, String> env;
}

/// Whether [error] is the dashboard saying the named server does not exist.
bool isMcpNotFound(Object error) =>
    error is DioException && error.response?.statusCode == 404;

/// Reads and changes the MCP servers of a Hermes profile through the
/// generated [DefaultApi].
///
/// The routes declare no response schemas, so the bodies are parsed by hand,
/// skipping rows that don't fit. Every call takes the `profile` to act on;
/// null leaves it to the dashboard. A missing server surfaces as a
/// [DioException] that [isMcpNotFound] recognises.
class HermesMcpRepository {
  HermesMcpRepository(this._api);

  final DefaultApi _api;

  /// Hermes has no structured code for "no OAuth token". A server that
  /// answers without one gets the first wording; one that refuses to start the
  /// browser flow inside the dashboard gets the second.
  static bool _isMissingToken(String error) =>
      error.startsWith('OAuth authentication required') ||
      (error.startsWith('MCP OAuth for') &&
          error.contains('no cached tokens found'));

  static String? _text(Object? value) => value is String ? value : null;

  static int? _count(Object? value) => value is num ? value.toInt() : null;

  static List<String> _texts(Object? value) => [
    if (value case final List<dynamic> items) ...items.whereType<String>(),
  ];

  static McpTransport _transport(Object? value) => switch (value) {
    'http' => McpTransport.remote,
    'stdio' => McpTransport.command,
    _ => McpTransport.unknown,
  };

  /// Runs [call] and turns the refusals Hermes explains (400, 409, 429) into
  /// [McpRefused]. Anything else, a 404 included, stays a [DioException].
  static Future<T> _refusing<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 409 || status == 429) {
        final reason = switch (e.response?.data) {
          {'detail': final String detail} => detail,
          _ => '',
        };
        throw McpRefused(status!, reason);
      }
      rethrow;
    }
  }

  Future<List<HermesMcpServer>> loadServers({String? profile}) async {
    final response = await _api.listMcpServersApiMcpServersGet(
      profile: profile,
    );
    final rows = switch (response.data) {
      {'servers': final List<dynamic> rows} => rows,
      _ => throw const FormatException('Unexpected MCP servers response'),
    };
    return [
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row['name'] case final String name when name.isNotEmpty)
          HermesMcpServer(
            name: name,
            transport: _transport(row['transport']),
            url: _text(row['url']),
            command: _text(row['command']),
            args: _texts(row['args']),
            auth: _text(row['auth']),
            enabled: row['enabled'] != false,
          ),
    ];
  }

  /// Adds [server] to the profile. Refusals (409 for a name that exists, 400
  /// with Hermes' reason, including a command it finds suspicious) surface as
  /// [McpRefused]. The request body can hold a token or environment values and
  /// is not kept.
  Future<void> addServer(McpNewServer server, {String? profile}) async {
    final body = switch (server) {
      McpNewRemoteServer() => MCPServerCreate(
        name: server.name,
        url: server.url,
        args: null,
        env: null,
        auth: switch (server.auth) {
          McpRemoteAuth.none => 'none',
          McpRemoteAuth.bearerToken => 'header',
          McpRemoteAuth.oauth => 'oauth',
        },
        bearerToken: server.auth == McpRemoteAuth.bearerToken
            ? server.bearerToken
            : null,
      ),
      McpNewCommandServer() => MCPServerCreate(
        name: server.name,
        command: server.command,
        args: server.args.isEmpty ? null : server.args,
        env: server.env.isEmpty ? null : server.env,
      ),
    };
    await _refusing(
      () => _api.addMcpServerApiMcpServersPost(
        mCPServerCreate: body,
        profile: profile,
      ),
    );
  }

  /// Replaces the profile's whole `mcp_servers` map with [servers]. Hermes
  /// checks every entry and refuses the save as a whole ([McpRefused], see
  /// [McpRefused.problems]). A field that is null is left out: Hermes reads it
  /// as unset and the request model cannot carry one.
  Future<void> replaceServers(
    Map<String, Map<String, Object?>> servers, {
    String? profile,
  }) async {
    await _refusing(
      () => _api.replaceMcpServersApiMcpServersPut(
        mCPServersReplace: MCPServersReplace(
          servers: {
            for (final server in servers.entries)
              server.key: {
                for (final field in server.value.entries)
                  if (field.value case final Object value) field.key: value,
              },
          },
          profile: profile,
        ),
        profile: profile,
      ),
    );
  }

  /// The profile's whole `mcp_servers` map as stored, from `GET /api/config`;
  /// empty when there is none. The servers route leaves out headers, OAuth
  /// settings and timeouts, so it cannot stand in for this. Entries that are
  /// not objects are kept so the user can see them.
  Future<Map<String, Object?>> loadRawServers({String? profile}) async {
    final response = await _api.getConfigApiConfigGet(profile: profile);
    final body = response.data;
    if (body is! Map) throw const FormatException('Unexpected config response');
    return switch (body['mcp_servers']) {
      null => <String, Object?>{},
      final Map<dynamic, dynamic> servers => {
        for (final entry in servers.entries) '${entry.key}': entry.value,
      },
      _ => throw const FormatException('Unexpected mcp_servers in config'),
    };
  }

  Future<void> setEnabled(String name, bool enabled, {String? profile}) async {
    await _api.setMcpServerEnabledApiMcpServersNameEnabledPut(
      name: Uri.encodeComponent(name),
      mCPEnabledToggle: MCPEnabledToggle(enabled: enabled),
      profile: profile,
    );
  }

  /// Connects to [server], lists what it offers and disconnects. A command
  /// server that has to fetch packages first can take many seconds.
  Future<HermesMcpTestResult> testServer(
    HermesMcpServer server, {
    String? profile,
  }) async {
    final response = await _api.testMcpServerApiMcpServersNameTestPost(
      name: Uri.encodeComponent(server.name),
      profile: profile,
    );
    final body = response.data;
    if (body is! Map || body['ok'] is! bool) {
      throw const FormatException('Unexpected MCP test response');
    }
    if (body['ok'] != true) {
      final error = _text(body['error']) ?? '';
      return HermesMcpTestResult(
        ok: false,
        error: error,
        signInNeeded: server.usesOAuth && _isMissingToken(error),
      );
    }
    return HermesMcpTestResult(
      ok: true,
      tools: [
        if (body['tools'] case final List<dynamic> tools)
          for (final tool in tools.whereType<Map<String, dynamic>>())
            if (tool['name'] case final String name when name.isNotEmpty)
              HermesMcpTool(
                name: name,
                description: _text(tool['description']) ?? '',
                schemaChars: _count(tool['schema_chars']),
              ),
      ],
      prompts: _count(body['prompts']) ?? 0,
      resources: _count(body['resources']) ?? 0,
    );
  }

  Future<void> removeServer(String name, {String? profile}) async {
    await _api.removeMcpServerApiMcpServersNameDelete(
      name: Uri.encodeComponent(name),
      profile: profile,
    );
  }

  Future<HermesMcpCatalog> loadCatalog({String? profile}) async {
    final response = await _api.listMcpCatalogApiMcpCatalogGet(
      profile: profile,
    );
    final body = response.data;
    if (body is! Map || body['entries'] is! List) {
      throw const FormatException('Unexpected MCP catalog response');
    }
    return HermesMcpCatalog(
      entries: [
        for (final row in (body['entries'] as List).whereType<Map>())
          if (row['name'] case final String name when name.isNotEmpty)
            HermesMcpCatalogEntry(
              name: name,
              transport: _transport(row['transport']),
              description: _text(row['description']) ?? '',
              source: _text(row['source']) ?? '',
              authKind: switch (row['auth_type']) {
                null || 'none' => McpAuthKind.none,
                'api_key' => McpAuthKind.apiKey,
                'oauth' => McpAuthKind.oauth,
                _ => McpAuthKind.unknown,
              },
              requiredEnv: [
                if (row['required_env'] case final List<dynamic> env)
                  for (final spec in env.whereType<Map>())
                    if (spec['name'] case final String key when key.isNotEmpty)
                      HermesMcpCredential(
                        name: key,
                        prompt: _text(spec['prompt']) ?? key,
                        required: spec['required'] != false,
                      ),
              ],
              command: _text(row['command']),
              args: _texts(row['args']),
              url: _text(row['url']),
              installUrl: _text(row['install_url']),
              installRef: _text(row['install_ref']),
              bootstrap: _texts(row['bootstrap']),
              installed: row['installed'] == true,
              enabled: row['enabled'] == true,
            ),
      ],
      hasDiagnostics: switch (body['diagnostics']) {
        final List<dynamic> found => found.isNotEmpty,
        _ => false,
      },
    );
  }

  /// Installs [entry]. Only the credentials it declares are sent, and empty
  /// ones are left out. A refusal (400) surfaces as [McpRefused]; an entry
  /// Hermes no longer has, as a 404 [DioException].
  Future<HermesMcpInstallResult> installEntry(
    HermesMcpCatalogEntry entry, {
    Map<String, String> env = const {},
    bool enable = true,
    String? profile,
  }) async {
    final declared = {for (final spec in entry.requiredEnv) spec.name};
    final response = await _refusing(
      () => _api.installMcpCatalogEntryApiMcpCatalogInstallPost(
        mCPCatalogInstall: MCPCatalogInstall(
          name: entry.name,
          env: {
            for (final e in env.entries)
              if (declared.contains(e.key) && e.value.isNotEmpty)
                e.key: e.value,
          },
          enable: enable,
        ),
        profile: profile,
      ),
    );
    final body = response.data;
    if (body is! Map || body['ok'] != true) {
      throw const FormatException('Unexpected MCP install response');
    }
    final action = body['background'] == true ? _text(body['action']) : null;
    if (body['background'] == true && action == null) {
      throw const FormatException('Install has no action to follow');
    }
    return HermesMcpInstallResult(
      name: _text(body['name']) ?? entry.name,
      action: action,
    );
  }

  Future<HermesMcpAction> actionStatus(String action) async {
    final response = await _api.getActionStatusApiActionsNameStatusGet(
      name: Uri.encodeComponent(action),
    );
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Unexpected action status response');
    }
    return HermesMcpAction(
      running: body['running'] == true,
      exitCode: _count(body['exit_code']),
      lines: _texts(body['lines']),
    );
  }

  /// Starts a sign-in for an OAuth server on Hermes. The flow's
  /// [HermesMcpFlow.authorizationUrl] is where the user approves it.
  Future<HermesMcpFlow> startSignIn(String name, {String? profile}) async {
    final response = await _refusing(
      () => _api.authMcpServerApiMcpServersNameAuthPost(
        name: Uri.encodeComponent(name),
        profile: profile,
      ),
    );
    return _flow(response.data);
  }

  /// The state of a flow. A flow Hermes has dropped is a 404
  /// [DioException].
  Future<HermesMcpFlow> flowStatus(String flowId) async {
    final response = await _api.mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet(
      flowId: Uri.encodeComponent(flowId),
    );
    return _flow(response.data);
  }

  /// Ends a flow so its server can start another. Hermes treats a flow it no
  /// longer has as already cancelled.
  Future<void> cancelFlow(String flowId) async {
    await _api.cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete(
      flowId: Uri.encodeComponent(flowId),
    );
  }

  static HermesMcpFlow _flow(Object? body) {
    if (body is! Map || body['flow_id'] is! String) {
      throw const FormatException('Unexpected MCP sign-in response');
    }
    return HermesMcpFlow(
      flowId: body['flow_id'] as String,
      status: switch (body['status']) {
        'starting' => McpFlowStatus.starting,
        'authorization_required' => McpFlowStatus.authorizationRequired,
        'approved' => McpFlowStatus.approved,
        'error' => McpFlowStatus.error,
        _ => McpFlowStatus.unknown,
      },
      authorizationUrl: _text(body['authorization_url']),
      error: _text(body['error']),
    );
  }
}
