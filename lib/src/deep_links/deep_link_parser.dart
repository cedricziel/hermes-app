import 'package:characters/characters.dart';

import 'deep_link_target.dart';

/// The longest prompt a link may put in the composer.
const deepLinkPromptLimit = 4000;

const _hosts = {'chat', 'new', 'requests', 'kanban', 'schedules'};

/// Whether [uri] is in the `hermes` scheme. app_links also delivers the
/// `hermes-activity`, `hermes-share` and `ShareMedia-*` URLs, which are not
/// ours to read or to note.
bool isHermesLink(Uri uri) => uri.scheme.toLowerCase() == 'hermes';

/// Why [parseDeepLink] returned null for [uri], as the fixed word a breadcrumb
/// carries: a known kind of link that could not be read (a missing required
/// parameter, a path-style `hermes:chat`) is `malformed`, anything else
/// `unknown`.
String deepLinkIgnoredReason(Uri uri) {
  final kind = (uri.host.isNotEmpty ? uri.host : uri.path).toLowerCase();
  return _hosts.contains(kind) ? 'malformed' : 'unknown';
}

/// The `hermes://` link [uri] stands for, or null when it is not one the app
/// knows or cannot be read. The host is the kind of link; query values are
/// decoded once (a `+` reads as a space, so producers write `%2B`), empty ones
/// count as absent and unknown keys are ignored.
DeepLinkTarget? parseDeepLink(Uri uri) {
  if (!isHermesLink(uri) || uri.host.isEmpty) return null;
  final Map<String, String> query;
  try {
    query = uri.queryParameters;
  } on FormatException {
    // An invalid percent escape, such as a cut-off UTF-8 sequence.
    return null;
  }
  String? value(String key) {
    final text = query[key];
    return text == null || text.isEmpty ? null : text;
  }

  String? prompt() {
    final text = value('prompt')?.trim();
    if (text == null || text.isEmpty) return null;
    return text.characters.take(deepLinkPromptLimit).toString();
  }

  return switch (uri.host.toLowerCase()) {
    'chat' => switch (value('id')) {
      final id? => OpenChat(
        profile: value('profile'),
        threadId: id,
        prompt: prompt(),
      ),
      null => null,
    },
    'new' => NewChat(
      profile: value('profile'),
      dictate: const {'1', 'true'}.contains(value('dictate')),
      prompt: prompt(),
    ),
    'requests' => const OpenRequests(),
    'kanban' => const OpenKanban(),
    'schedules' => OpenSchedules(
      profile: value('profile'),
      jobId: value('job'),
    ),
    _ => null,
  };
}
