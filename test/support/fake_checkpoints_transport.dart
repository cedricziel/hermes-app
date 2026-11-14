import 'dart:async';

import 'package:hermes_app/src/chat/checkpoints/chat_action_bridge.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_transport.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';

/// Scripted `rollback.*`, `session.context_breakdown` and `session.compress`
/// answers. Every call is recorded, with the thread and values it was sent.
class FakeCheckpointsTransport
    implements CheckpointsTransport, ContextTransport {
  CheckpointList list = const CheckpointsOn([]);
  CheckpointChanges changes = const ChangesUnreadable();
  CheckpointRestore restore = const Restored();
  ContextBreakdown breakdown = const Breakdown(categories: []);
  CompressionResult compress = const Compressed();

  /// When set, the call waits for it.
  Completer<void>? listGate,
      changesGate,
      restoreGate,
      breakdownGate,
      compressGate;

  /// Replaces [list] for the next calls, in order, before falling back.
  final listQueue = <CheckpointList>[];

  final calls = <String>[];
  final restoreRequests =
      <({String thread, String? profile, String hash, String? file})>[];
  final compressRequests =
      <({String thread, String? profile, String? focus})>[];

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;

  @override
  Future<CheckpointList> listCheckpoints(OwnedSessionBinding binding) async {
    calls.add('list');
    final answer = listQueue.isEmpty ? list : listQueue.removeAt(0);
    await listGate?.future;
    return answer;
  }

  @override
  Future<CheckpointList> listCheckpointsResuming(
    String threadId, {
    String? profile,
  }) async {
    calls.add('listResuming');
    return list;
  }

  @override
  Future<CheckpointChanges> checkpointChanges(
    OwnedSessionBinding binding,
    String hash,
  ) async {
    calls.add('changes:$hash');
    await changesGate?.future;
    return changes;
  }

  @override
  Future<CheckpointRestore> restoreCheckpoint(
    String threadId, {
    String? profile,
    required String hash,
    String? filePath,
  }) async {
    calls.add('restore');
    restoreRequests.add((
      thread: threadId,
      profile: profile,
      hash: hash,
      file: filePath,
    ));
    await restoreGate?.future;
    return restore;
  }

  @override
  Future<ContextBreakdown> contextBreakdown(OwnedSessionBinding binding) async {
    calls.add('breakdown');
    await breakdownGate?.future;
    return breakdown;
  }

  @override
  Future<CompressionResult> compressSession(
    String threadId, {
    String? profile,
    String? focus,
  }) async {
    calls.add('compress');
    compressRequests.add((thread: threadId, profile: profile, focus: focus));
    await compressGate?.future;
    return compress;
  }
}

/// A chat around a controller, scripted.
class FakeChatBridge {
  bool replying = false, hasEdits = false;
  PromptQuote? quote;
  bool quoteStillThere = false;
  final held = <bool>[];
  final handedBack = <String>[];
  int refetches = 0, usageReads = 0, reestablished = 0;

  ChatActionBridge get bridge => ChatActionBridge(
    isReplying: () => replying,
    refetchChat: () async => refetches++,
    refreshUsage: () async => usageReads++,
    holdSend: held.add,
    lastPrompt: () => quote,
    chatHolds: (_) => quoteStillThere,
    handBackToComposer: handedBack.add,
    hasEditToolCall: () => hasEdits,
    reestablishSession: () async => reestablished++,
  );
}

final fakeConnection = Object();

OwnedSessionBinding fakeBinding({
  String runtime = 'rt-1',
  String? profile = 'work',
}) => OwnedSessionBinding(
  connection: fakeConnection,
  runtimeId: runtime,
  profile: profile,
);

ActionScope fakeScope({String thread = 'stored-1', bool live = true}) =>
    ActionScope(
      threadId: thread,
      profile: 'work',
      binding: live ? fakeBinding() : null,
    );
