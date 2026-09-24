import 'dart:typed_data';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import '../chat/hermes_chat_repository.dart';
import '../notifications/attention_policy.dart';

/// Answers the requests the watch app relays through the phone. Requests and
/// replies are plain maps of property-list types, the shape WatchConnectivity
/// carries: `{'op': 'threads' | 'messages' | 'send' | 'transcribe', ...}` in, `{'ok': true,
/// ...}` or `{'ok': false, 'error': 'signed_out' | 'bad_request' | 'failed'}`
/// out.
///
/// The watch shows a glance, so lists are cut to what fits on it.
///
/// A thread id the watch sees is tied to the profile it was listed under
/// (`<encoded profile>/<session id>`), because the same session id can exist in
/// two profiles. The watch treats it as opaque and hands it back; a request
/// whose profile is no longer the active one is refused as `bad_request`.
class WatchRequestHandler {
  WatchRequestHandler({
    required this.repository,
    required this.transport,
    required this.activeProfile,
    this.connecting = _never,
    this.sendTimeout = const Duration(seconds: 60),
    this.announce = _ignore,
  });

  /// What the watch is told when the agent asks for something only the phone's
  /// own chat could answer. It names neither the command nor the question.
  static const cannotAnswerText =
      "Hermes asked for something the watch can't answer. "
      'Ask again on your iPhone.';

  /// What the watch shows for a successful reply that has no text at all.
  static const emptyReplyText = 'Hermes replied without any text.';

  /// The title of a notification for a chat the gateway has not named.
  static const untitledChat = 'Hermes';

  static const threadLimit = 20;
  static const messageLimit = 20;
  static const contentLimit = 4000;

  /// Both return null while nobody is signed in.
  final HermesChatRepository? Function() repository;
  final ChatTransport? Function() transport;
  final Future<String?> Function() activeProfile;

  /// Whether the phone is still getting ready to serve, rather than signed
  /// out: restoring its session, reaching the server, or mid sign-in. Then
  /// the watch is told to open the phone app instead of to sign in.
  final bool Function() connecting;

  /// How long a send may go without an event before it is given up on.
  final Duration sendTimeout;

  /// Tells the user a turn they sent from the watch is over. The watch may
  /// have lost sight of it by then, so it is called whatever the phone shows.
  final void Function(AttentionNotification notification) announce;

  static void _ignore(AttentionNotification _) {}

  static bool _never() => false;

  Future<Map<String, Object?>> handle(Map<Object?, Object?> request) async {
    try {
      return switch (request['op']) {
        'threads' => await _threads(),
        'messages' => await _messages(request['threadId']),
        'send' => await _send(request['threadId'], request['text']),
        'transcribe' => await _transcribe(
          request['audio'],
          request['mimeType'],
        ),
        _ => _error('bad_request'),
      };
    } on Object {
      return _error('failed');
    }
  }

  Future<Map<String, Object?>> _threads() async {
    final repo = repository();
    if (repo == null) return _noSession();
    final profile = await activeProfile();
    final threads = await repo.loadThreads(
      limit: threadLimit,
      profile: profile,
    );
    return {
      'ok': true,
      'threads': [
        for (final thread in threads.take(threadLimit))
          {
            'id': _bind(profile, thread.id),
            'title': thread.title,
            'updatedAt': thread.updatedAt.millisecondsSinceEpoch ~/ 1000,
            'pinned': thread.pinned,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _messages(Object? threadId) async {
    final thread = _unbind(threadId);
    if (thread == null) return _error('bad_request');
    final repo = repository();
    if (repo == null) return _noSession();
    final profile = await activeProfile();
    if (!thread.isIn(profile)) return _error('bad_request');
    final messages = await repo.loadMessages(thread.id, profile: profile);
    return {
      'ok': true,
      'messages': [
        for (final message in messages.skip(
          messages.length > messageLimit ? messages.length - messageLimit : 0,
        ))
          {
            'id': message.id,
            'role': message.role == ChatRole.user ? 'user' : 'assistant',
            'content': _cut(message.content),
            'at': message.createdAt.millisecondsSinceEpoch ~/ 1000,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _transcribe(
    Object? audio,
    Object? mimeType,
  ) async {
    if (audio is! Uint8List || audio.isEmpty || mimeType is! String) {
      return _error('bad_request');
    }
    final repo = repository();
    if (repo == null) return _noSession();
    final text = await repo.transcribe(
      audio,
      mimeType: mimeType,
      profile: await activeProfile(),
    );
    return {'ok': true, 'text': text};
  }

  Future<Map<String, Object?>> _send(Object? threadId, Object? text) async {
    if (text is! String || text.trim().isEmpty) return _error('bad_request');
    final thread = threadId == null ? null : _unbind(threadId);
    if (threadId != null && thread == null) return _error('bad_request');
    final chat = transport();
    if (chat == null) return _noSession();
    String? profile;
    String? boundId;
    var title = untitledChat;
    final streamed = StringBuffer();
    void announceEnd(ChatEvent event) {
      final id = boundId;
      if (id == null) return;
      final notification = attentionFor(
        event: event,
        thread: ChatThread(id: id, title: title, updatedAt: DateTime.now()),
        appFocused: false,
        selectedThreadId: null,
        enabled: true,
        profile: profile,
      );
      if (notification != null) announce(notification);
    }

    try {
      profile = await activeProfile();
      if (thread != null && !thread.isIn(profile)) return _error('bad_request');
      boundId = thread?.id;
      final events = chat
          .send(threadId: boundId, profile: profile, text: text)
          .timeout(sendTimeout);
      await for (final event in events) {
        switch (event) {
          case ThreadBound(:final threadId):
            boundId = threadId;
          case ThreadTitled(title: final named):
            title = named;
          case ReplyDelta(:final text):
            streamed.write(text);
          case ReplyCompleted(:final text, :final failed):
            announceEnd(event);
            return {
              'ok': true,
              ..._threadEntry(profile, boundId),
              'text': _cut(failed ? text : _shown(text, streamed.toString())),
              'failed': failed,
            };
          case ApprovalRequested() ||
              ClarifyRequested() ||
              UnsupportedRequested():
            announceEnd(event);
            return {
              'ok': true,
              ..._threadEntry(profile, boundId),
              'text': cannotAnswerText,
              'failed': false,
            };
          default:
        }
      }
      announceEnd(const ReplyCompleted('', failed: true));
      return _error('failed');
    } on Object {
      announceEnd(const ReplyCompleted('', failed: true));
      rethrow;
    } finally {
      await chat.close();
    }
  }

  /// The `threadId` entry of a reply, left out when there is no thread: a null
  /// is not a property-list type and WatchConnectivity would refuse the reply.
  static Map<String, Object?> _threadEntry(String? profile, String? id) =>
      id == null ? const {} : {'threadId': _bind(profile, id)};

  static String _bind(String? profile, String sessionId) =>
      '${Uri.encodeComponent(profile ?? '')}/$sessionId';

  static _Thread? _unbind(Object? threadId) {
    if (threadId is! String) return null;
    final slash = threadId.indexOf('/');
    if (slash < 0 || slash == threadId.length - 1) return null;
    try {
      return _Thread(
        Uri.decodeComponent(threadId.substring(0, slash)),
        threadId.substring(slash + 1),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// The final [text] of a successful reply, else what streamed, else a note
  /// that there was nothing, so the watch never shows an empty bubble.
  static String _shown(String text, String streamed) {
    if (text.trim().isNotEmpty) return text;
    return streamed.trim().isNotEmpty ? streamed : emptyReplyText;
  }

  static String _cut(String text) => text.length <= contentLimit
      ? text
      : '${text.substring(0, contentLimit)}…';

  Map<String, Object?> _noSession() =>
      _error(connecting() ? 'unavailable' : 'signed_out');

  static Map<String, Object?> _error(String code) => {
    'ok': false,
    'error': code,
  };
}

class _Thread {
  const _Thread(this.profile, this.id);

  final String profile;
  final String id;

  bool isIn(String? active) => profile == (active ?? '');
}
