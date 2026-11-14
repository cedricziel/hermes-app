/// The `subagent.*` methods the app calls. A caller cannot name any other, so
/// nothing here can reach a call that stops or changes more than one agent.
const kAgentReadMethods = {'subagent.list', 'subagent.tail'};
const kAgentActionMethods = {'subagent.interrupt', 'subagent.steer'};

/// Calls on a chat's live session that only the connection holding it may
/// make. The transport adds `session_id` itself, so a caller never addresses
/// another session.
abstract interface class AgentWorkTransport {
  /// Reads [method] when the chat's session is attached on the current
  /// connection, and returns null, sending nothing, when it is not. Never
  /// resumes the session. A call that gets no answer within [timeout] throws
  /// `GatewayRequestTimeout` and leaves the connection alone.
  Future<Map<String, Object?>?> readAttached(
    String threadId, {
    String? profile,
    required String method,
    Map<String, Object?> params = const {},
    required Duration timeout,
  });

  /// Attaches the session with `session.resume` when it is not attached, then
  /// sends [method] once. Never resends.
  Future<Map<String, Object?>> act(
    String threadId, {
    String? profile,
    required String method,
    Map<String, Object?> params = const {},
    required Duration timeout,
  });
}
