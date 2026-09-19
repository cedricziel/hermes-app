import 'package:hermes_api/hermes_api.dart';

import 'chat_models.dart';

/// Loads chat threads and their messages from the Hermes dashboard through
/// the generated [DefaultApi].
///
/// The spec declares no response schemas for the session routes, so the
/// generated methods return untyped JSON; the row shapes parsed here follow
/// what the dashboard serialises (`sessions` / `messages` envelopes, epoch
/// seconds for timestamps, OpenAI-style `tool_calls`). Rows that don't fit
/// are skipped rather than failing the whole list.
class HermesChatRepository {
  HermesChatRepository(this._api);

  final DefaultApi _api;

  /// Most recently active sessions first. Threads come back without
  /// messages; fetch them with [loadMessages] when a thread is opened.
  ///
  /// Each profile keeps its sessions in its own database, so a session id is
  /// only unique within one. Without [profile] the dashboard answers for the
  /// profile it is scoped to, whatever the sticky active profile is.
  Future<List<ChatThread>> loadThreads({
    int limit = 50,
    String? profile,
  }) async {
    final response = await _api.getSessionsApiSessionsGet(
      limit: limit,
      order: 'recent',
      profile: profile,
    );
    final rows = _rows(response.data, 'sessions');
    return [
      for (final row in rows)
        if (row['id'] case final String id when id.isNotEmpty)
          ChatThread(
            id: id,
            title: _title(row),
            updatedAt: _time(row['last_active'] ?? row['started_at']),
          ),
    ];
  }

  /// [profile] must be the one [sessionId] was listed under: another profile
  /// may hold a different session with the same id.
  Future<List<ChatMessage>> loadMessages(
    String sessionId, {
    String? profile,
  }) async {
    final response = await _api
        .getSessionMessagesApiSessionsSessionIdMessagesGet(
          sessionId: sessionId,
          profile: profile,
        );
    final messages = <ChatMessage>[];
    for (final row in _rows(response.data, 'messages')) {
      final role = switch (row['role']) {
        'user' => ChatRole.user,
        'assistant' => ChatRole.assistant,
        _ => null,
      };
      if (role == null) continue;
      messages.add(
        ChatMessage(
          id: '$sessionId-${row['id']}',
          role: role,
          content: row['content'] as String? ?? '',
          createdAt: _time(row['timestamp']),
          toolCalls: _toolCalls(row['tool_calls']),
        ),
      );
    }
    return messages;
  }

  static List<Map<String, dynamic>> _rows(Object? body, String key) {
    final list = body is Map ? body[key] : null;
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  static String _title(Map<String, dynamic> row) {
    for (final key in const ['title', 'preview']) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return 'Untitled chat';
  }

  static DateTime _time(Object? epochSeconds) => epochSeconds is num
      ? DateTime.fromMillisecondsSinceEpoch((epochSeconds * 1000).round())
      : DateTime.fromMillisecondsSinceEpoch(0);

  static List<ToolCall> _toolCalls(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final call in raw.whereType<Map<String, dynamic>>())
        if (call['function'] case {'name': final String name} && final Map fn)
          ToolCall(name: name, summary: fn['arguments'] as String? ?? ''),
    ];
  }
}
