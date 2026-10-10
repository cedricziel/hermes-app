import 'deep_link_target.dart';

/// The `hermes://` link that opens [target]. Every producer of links builds
/// them here, so they cannot drift from what `parseDeepLink` reads.
Uri deepLinkUri(DeepLinkTarget target) {
  // Uri(queryParameters:) writes a space as "+", which Swift's URLComponents
  // reads back as a plus, so the query is built with %20 instead.
  Uri link(String host, Map<String, String?> parameters) {
    final pairs = [
      for (final MapEntry(:key, :value) in parameters.entries)
        if (value != null) '$key=${Uri.encodeComponent(value)}',
    ];
    return Uri(
      scheme: 'hermes',
      host: host,
      query: pairs.isEmpty ? null : pairs.join('&'),
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
