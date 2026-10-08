import 'hermes_mcp_repository.dart';

/// "Remote" or "Command", or null when the dashboard does not say.
String? mcpTransportLabel(McpTransport transport) => switch (transport) {
  McpTransport.remote => 'Remote',
  McpTransport.command => 'Command',
  McpTransport.unknown => null,
};

/// How a server signs in, or null for a command server that does not.
String? mcpAuthLabel(HermesMcpServer server) => switch (server.auth) {
  'oauth' => 'OAuth',
  'header' => 'Header',
  final other? when other.isNotEmpty => other,
  _ => server.transport == McpTransport.remote ? 'No auth' : null,
};

String mcpPlural(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';

String mcpSchemaSize(int chars) => chars < 1000
    ? '$chars chars'
    : '${(chars / 1000).toStringAsFixed(1)}k chars';

/// How a catalog entry signs in: "API key", "OAuth" or "No auth".
String? mcpAuthKindLabel(McpAuthKind kind) => switch (kind) {
  McpAuthKind.apiKey => 'API key',
  McpAuthKind.oauth => 'OAuth',
  McpAuthKind.none => 'No auth',
  McpAuthKind.unknown => null,
};

/// A server's facts on one line, such as "Remote · OAuth · 2 tools · Off":
/// the tool count once a test has listed them.
String mcpServerMeta(HermesMcpServer server, HermesMcpTestResult? tested) => [
  ?mcpTransportLabel(server.transport),
  ?mcpAuthLabel(server),
  if (tested != null && tested.ok) mcpPlural(tested.tools.length, 'tool'),
  if (!server.enabled) 'Off',
].join(' · ');
