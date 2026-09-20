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
