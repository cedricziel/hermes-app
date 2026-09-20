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
class WatchRequestHandler {
  WatchRequestHandler({
    required this.repository,
    required this.transport,
    required this.activeProfile,
  });

  static const threadLimit = 20;
  static const messageLimit = 20;
  static const contentLimit = 4000;

  /// Both return null while nobody is signed in.
  final HermesChatRepository? Function() repository;
  final ChatTransport? Function() transport;
  final Future<String?> Function() activeProfile;

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
    final threads = await repo.loadThreads(
      limit: threadLimit,
      profile: await activeProfile(),
    );
    return {
      'ok': true,
      'threads': [
        for (final thread in threads)
          {
            'id': thread.id,
            'title': thread.title,
            'updatedAt': thread.updatedAt.millisecondsSinceEpoch ~/ 1000,
            'pinned': thread.pinned,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _messages(Object? threadId) async {
    if (threadId is! String || threadId.isEmpty) return _error('bad_request');
    final repo = repository();
    if (repo == null) return _error('signed_out');
    final messages = await repo.loadMessages(
      threadId,
      profile: await activeProfile(),
    );
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
    if (threadId != null && threadId is! String) return _error('bad_request');
    final chat = transport();
    if (chat == null) return _error('signed_out');
    try {
      var boundId = threadId as String?;
      await for (final event in chat.send(threadId: boundId, text: text)) {
        switch (event) {
          case ThreadBound(:final threadId):
            boundId = threadId;
          case ReplyCompleted(:final text, :final failed):
            return {
              'ok': true,
              'threadId': boundId,
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

  static String _cut(String text) => text.length <= contentLimit
      ? text
      : '${text.substring(0, contentLimit)}…';

  static Map<String, Object?> _error(String code) => {
    'ok': false,
    'error': code,
  };
}
