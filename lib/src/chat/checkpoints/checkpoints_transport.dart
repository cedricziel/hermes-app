import '../context/context_models.dart';
import '../owned_session_transport.dart';
import 'checkpoint_models.dart';

/// `rollback.*`, over the gateway. Reads take the binding of a runtime the
/// chat already owns and never create or resume a session; [listCheckpointsResuming],
/// [restoreCheckpoint] and [compressSession] act on an explicit tap and
/// resume the stored chat when it has no live runtime.
///
/// Nothing here is sent twice: a request whose answer is lost ends as
/// [RestoreMayHaveHappened] or [CompressMayHaveHappened] and the caller
/// re-reads.
abstract interface class CheckpointsTransport {
  Future<CheckpointList> listCheckpoints(OwnedSessionBinding binding);

  Future<CheckpointList> listCheckpointsResuming(
    String threadId, {
    String? profile,
  });

  /// [hash] is the full hash of a listed checkpoint.
  Future<CheckpointChanges> checkpointChanges(
    OwnedSessionBinding binding,
    String hash,
  );

  /// Restores one file when [filePath] is given (a path read from `stat`),
  /// otherwise every file, which also rewinds the chat's last turn.
  Future<CheckpointRestore> restoreCheckpoint(
    String threadId, {
    String? profile,
    required String hash,
    String? filePath,
  });
}

/// `session.context_breakdown` and `session.compress`, over the gateway, with
/// the same rules as [CheckpointsTransport].
abstract interface class ContextTransport {
  Future<ContextBreakdown> contextBreakdown(OwnedSessionBinding binding);

  /// [focus] must pass [isAcceptableFocus]; the call throws [ArgumentError]
  /// otherwise, before anything is sent.
  Future<CompressionResult> compressSession(
    String threadId, {
    String? profile,
    String? focus,
  });
}
