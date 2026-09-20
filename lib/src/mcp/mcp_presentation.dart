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

/// From this width in logical pixels the MCP screens put a detail or form
/// beside the list, or in a dialog, instead of on a page or sheet.
const double mcpWideBreakpoint = 900;
