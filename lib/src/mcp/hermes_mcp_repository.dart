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

  @override
  String toString() => 'HermesMcpServer($name)';
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

  static const _signInPrefix = 'OAuth authentication required';

  static String? _text(Object? value) => value is String ? value : null;

  static int? _count(Object? value) => value is num ? value.toInt() : null;

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
            transport: switch (row['transport']) {
              'http' => McpTransport.remote,
              'stdio' => McpTransport.command,
              _ => McpTransport.unknown,
            },
            url: _text(row['url']),
            command: _text(row['command']),
            args: [
              if (row['args'] case final List<dynamic> args)
                ...args.whereType<String>(),
            ],
            auth: _text(row['auth']),
            enabled: row['enabled'] != false,
          ),
    ];
  }

  Future<void> setEnabled(String name, bool enabled, {String? profile}) async {
    await _api.setMcpServerEnabledApiMcpServersNameEnabledPut(
      name: name,
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
      name: server.name,
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
        signInNeeded: server.usesOAuth && error.startsWith(_signInPrefix),
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
      name: name,
      profile: profile,
    );
  }
}
