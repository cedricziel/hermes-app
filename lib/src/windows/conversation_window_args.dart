import 'dart:convert';

import '../share/shared_item.dart';

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
}

/// What the main window's composer held for a chat it hands to a window, so
/// the text and files move with the chat instead of staying behind.
class ConversationDraft {
  const ConversationDraft({this.text = '', this.files = const []});

  final String text;
  final List<SharedFile> files;

  bool get isEmpty => text.isEmpty && files.isEmpty;

  Map<String, Object?> toJson() => {
    'text': text,
    'files': [
      for (final f in files)
        {
          'path': f.path,
          'name': f.name,
          'mime_type': f.mimeType,
          'is_image': f.isImage,
        },
    ],
  };

  static ConversationDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    final files = json['files'];
    return ConversationDraft(
      text: text is String ? text : '',
      files: [
        if (files is List)
          for (final f in files.whereType<Map<Object?, Object?>>())
            if (f['path'] case final String path)
              SharedFile(
                path: path,
                name: f['name'] is String ? f['name']! as String : path,
                mimeType: f['mime_type'] is String
                    ? f['mime_type']! as String
                    : null,
                isImage: f['is_image'] == true,
              ),
      ],
    );
  }
}

/// What a conversation window's engine is started with: its [args], and the
/// [draft] it takes over, which is never saved for the next launch.
class ConversationWindowLaunch {
  const ConversationWindowLaunch(this.args, {this.draft});

  final ConversationWindowArgs args;
  final ConversationDraft? draft;

  String encode() => jsonEncode({...args.toJson(), 'draft': ?draft?.toJson()});

  /// Null for anything that is not a window's arguments.
  static ConversationWindowLaunch? decode(String source) {
    try {
      final json = jsonDecode(source);
      final args = ConversationWindowArgs.fromJson(json);
      if (args == null) return null;
      return ConversationWindowLaunch(
        args,
        draft: ConversationDraft.fromJson((json as Map)['draft']),
      );
    } on FormatException {
      return null;
    }
  }
}
