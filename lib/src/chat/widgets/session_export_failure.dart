/// Why a chat export ended without a file. One kind per message of the export
/// alert; the controller maps what the server did to one of them.
enum SessionExportFailure {
  /// The server no longer has the chat (404 `Session not found`).
  gone(canRetry: false),

  /// The server has no export route.
  unsupported(canRetry: false),

  /// The chat's profile does not exist on the server (404).
  profileMissing(canRetry: false),

  /// The server rejected the chat's profile name (400).
  profileInvalid(canRetry: false),

  /// The server's chat store could not be read (503).
  unreadable(canRetry: true),

  /// Nothing arrived in time.
  lost(canRetry: true),

  /// The body stopped before the end or is not a whole session.
  incomplete(canRetry: true),

  /// The device is offline.
  offline(canRetry: true),

  /// Any other status or error.
  failed(canRetry: true);

  const SessionExportFailure({required this.canRetry});

  /// Whether trying again can help; the alert offers Try again only then.
  final bool canRetry;
}
