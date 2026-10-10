import 'deep_link_target.dart';

/// The longest prompt a link may put in the composer.
const deepLinkPromptLimit = 4000;

/// The `hermes://` link [uri] stands for, or null when it is not one the app
/// knows. The host is the kind of link; query values are decoded once, empty
/// ones count as absent and unknown keys are ignored.
DeepLinkTarget? parseDeepLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'hermes' || uri.host.isEmpty) return null;
  final query = uri.queryParameters;
  String? value(String key) {
    final text = query[key];
    return text == null || text.isEmpty ? null : text;
  }

  String? prompt() {
    final text = value('prompt')?.trim();
    if (text == null || text.isEmpty) return null;
    return text.length > deepLinkPromptLimit
        ? text.substring(0, deepLinkPromptLimit)
        : text;
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
