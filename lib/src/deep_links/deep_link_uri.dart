import 'deep_link_target.dart';

/// The `hermes://` link that opens [target]. Every producer of links builds
/// them here, so they cannot drift from what `parseDeepLink` reads.
Uri deepLinkUri(DeepLinkTarget target) {
  Uri link(String host, Map<String, String?> parameters) {
    final set = <String, String>{
      for (final MapEntry(:key, :value) in parameters.entries) key: ?value,
    };
    // An empty map would still write a trailing `?`.
    return Uri(
      scheme: 'hermes',
      host: host,
      queryParameters: set.isEmpty ? null : set,
    );
  }

  return switch (target) {
    OpenChat() => link('chat', {
      'profile': target.profile,
      'id': target.threadId,
      'prompt': target.prompt,
    }),
    NewChat() => link('new', {
      'profile': target.profile,
      'dictate': target.dictate ? '1' : null,
      'prompt': target.prompt,
    }),
    OpenRequests() => link('requests', {}),
    OpenKanban() => link('kanban', {}),
    OpenSchedules() => link('schedules', {
      'profile': target.profile,
      'job': target.jobId,
    }),
  };
}
