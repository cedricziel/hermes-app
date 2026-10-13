import 'dart:async';

class OwnedSessionBinding {
  const OwnedSessionBinding({
    required this.connection,
    required this.runtimeId,
    required this.profile,
  });
  final Object connection;
  final String runtimeId;
  final String? profile;

  @override
  bool operator ==(Object other) =>
      other is OwnedSessionBinding &&
      identical(connection, other.connection) &&
      runtimeId == other.runtimeId &&
      profile == other.profile;
  @override
  int get hashCode =>
      Object.hash(identityHashCode(connection), runtimeId, profile);
}

class OwnedSessionChange {
  const OwnedSessionChange(
    this.threadId,
    this.binding, {
    this.connected = true,
    this.retired = false,
    this.resuming = false,
    this.resumeToken,
    this.resumeSnapshot,
  });
  final String threadId;
  final OwnedSessionBinding binding;
  final bool connected, retired, resuming;
  final Object? resumeToken;
  final Map<String, Object?>? resumeSnapshot;
}

abstract interface class OwnedSessionTransport {
  /// Reports established attachments and loss of their exact connection token.
  Stream<OwnedSessionChange> get ownedSessions;

  /// Returns only an already confirmed runtime; this lookup never resumes a chat.
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile});

  /// Reads an existing optional method on this binding without dropping its socket.
  /// Rejects unsupported methods and bindings that lost their current ownership.
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  );
}
