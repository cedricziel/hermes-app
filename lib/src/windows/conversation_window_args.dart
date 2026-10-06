import 'dart:convert';

/// What a conversation window is opened with: the chat, the profile it
/// stays on, and the server it belongs to. Holds no secret, since it is
/// passed to the window's engine and kept in preferences for the next launch.
class ConversationWindowArgs {
  const ConversationWindowArgs({
    required this.threadId,
    required this.profile,
    required this.title,
    required this.baseUrl,
    required this.authRequired,
  });

  final String threadId;

  /// Null on a dashboard that has no profiles.
  final String? profile;
  final String title;
  final String baseUrl;
  final bool authRequired;

  /// The name the window's frame is saved under, so it reopens where it was.
  String get frameName => 'conversation:$baseUrl:${profile ?? ''}:$threadId';

  /// Whether this is the window of [threadId] on [profile].
  bool shows(String threadId, String? profile) =>
      this.threadId == threadId && this.profile == profile;

  ConversationWindowArgs withTitle(String title) => ConversationWindowArgs(
    threadId: threadId,
    profile: profile,
    title: title,
    baseUrl: baseUrl,
    authRequired: authRequired,
  );

  Map<String, Object?> toJson() => {
    'thread_id': threadId,
    'profile': profile,
    'title': title,
    'base_url': baseUrl,
    'auth_required': authRequired,
  };

  String encode() => jsonEncode(toJson());

  /// Null for anything that is not a window's arguments.
  static ConversationWindowArgs? fromJson(Object? json) {
    if (json is! Map) return null;
    final threadId = json['thread_id'];
    final baseUrl = json['base_url'];
    if (threadId is! String || threadId.isEmpty || baseUrl is! String) {
      return null;
    }
    final profile = json['profile'];
    final title = json['title'];
    return ConversationWindowArgs(
      threadId: threadId,
      profile: profile is String ? profile : null,
      title: title is String ? title : '',
      baseUrl: baseUrl,
      authRequired: json['auth_required'] != false,
    );
  }

  static ConversationWindowArgs? decode(String source) {
    try {
      return fromJson(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }
}
