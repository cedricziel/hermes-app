import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import '../chat/hermes_chat_repository.dart';

/// Answers the requests the watch app relays through the phone. Requests and
/// replies are plain maps of property-list types, the shape WatchConnectivity
/// carries: `{'op': 'threads' | 'messages' | 'send', ...}` in, `{'ok': true,
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
    this.sendTimeout = const Duration(seconds: 60),
  });

  static const threadLimit = 20;
  static const messageLimit = 20;
  static const contentLimit = 4000;

  /// Both return null while nobody is signed in.
  final HermesChatRepository? Function() repository;
  final ChatTransport? Function() transport;
  final Future<String?> Function() activeProfile;

  /// How long a send may go without an event before it is given up on.
  final Duration sendTimeout;

  Future<Map<String, Object?>> handle(Map<Object?, Object?> request) async {
    try {
      return switch (request['op']) {
        'threads' => await _threads(),
        'messages' => await _messages(request['threadId']),
        'send' => await _send(request['threadId'], request['text']),
        _ => _error('bad_request'),
      };
    } on Object {
      return _error('failed');
    }
  }

  Future<Map<String, Object?>> _threads() async {
    final repo = repository();
    if (repo == null) return _error('signed_out');
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
    if (repo == null) return _error('signed_out');
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

  Future<Map<String, Object?>> _send(Object? threadId, Object? text) async {
    if (text is! String || text.trim().isEmpty) return _error('bad_request');
    final thread = threadId == null ? null : _unbind(threadId);
    if (threadId != null && thread == null) return _error('bad_request');
    final chat = transport();
    if (chat == null) return _error('signed_out');
    try {
      final profile = await activeProfile();
      if (thread != null && !thread.isIn(profile)) return _error('bad_request');
      var boundId = thread?.id;
      final events = chat
          .send(threadId: boundId, profile: profile, text: text)
          .timeout(sendTimeout);
      await for (final event in events) {
        switch (event) {
          case ThreadBound(:final threadId):
            boundId = threadId;
          case ReplyCompleted(:final text, :final failed):
            return {
              'ok': true,
              'threadId': boundId == null ? null : _bind(profile, boundId),
              'text': _cut(text),
              'failed': failed,
            };
          default:
        }
      }
      return _error('failed');
    } finally {
      await chat.close();
    }
  }

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

  static String _cut(String text) => text.length <= contentLimit
      ? text
      : '${text.substring(0, contentLimit)}…';

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
