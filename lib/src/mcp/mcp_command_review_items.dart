import 'hermes_mcp_repository.dart';

/// What a command server would run: the command, its arguments and the names
/// of its environment variables. Values are not kept, so nothing that shows
/// an item can show a secret.
class McpCommandReviewItem {
  const McpCommandReviewItem({
    required this.name,
    required this.command,
    this.args = const [],
    this.envNames = const [],
  });

  factory McpCommandReviewItem.of(McpNewCommandServer server) =>
      McpCommandReviewItem(
        name: server.name,
        command: server.command,
        args: server.args,
        envNames: server.env.keys.toList(),
      );

  /// Reads a server entry of the profile's config. Values that are not the
  /// shape Hermes documents are shown as text rather than left out.
  factory McpCommandReviewItem.fromConfig(
    String name,
    Map<String, Object?> config,
  ) => McpCommandReviewItem(
    name: name,
    command: '${config['command']}',
    args: switch (config['args']) {
      null => const [],
      final List<Object?> args => [for (final arg in args) '$arg'],
      final other => ['$other'],
    },
    envNames: switch (config['env']) {
      final Map<Object?, Object?> env => [for (final k in env.keys) '$k'],
      _ => const [],
    },
  );

  final String name;
  final String command;
  final List<String> args;
  final List<String> envNames;
}

bool _isCommandServer(Map<String, Object?> config) => config['command'] != null;

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        [for (var i = 0; i < a.length; i++) _same(a[i], b[i])].every((s) => s);
  }
  return a == b;
}

/// The command servers of [next] that would start running something [loaded]
/// did not have: a name that is new, or a `command`, `args` or `env` (names or
/// values, since a value such as `NODE_OPTIONS` changes what runs) that
/// differs. Removed servers and other changes are not listed.
List<McpCommandReviewItem> commandServersToReview(
  Map<String, Object?> loaded,
  Map<String, Map<String, Object?>> next,
) {
  return [
    for (final entry in next.entries)
      if (_isCommandServer(entry.value) &&
          switch (loaded[entry.key]) {
            final Map<Object?, Object?> before =>
              !_same(before['command'], entry.value['command']) ||
                  !_same(before['args'], entry.value['args']) ||
                  !_same(before['env'], entry.value['env']),
            _ => true,
          })
        McpCommandReviewItem.fromConfig(entry.key, entry.value),
  ];
}
