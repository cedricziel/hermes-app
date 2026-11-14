import 'dart:async';

import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_transport.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/session_usage/usage_snapshot.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';

import 'fake_chat_transport.dart';
import 'fake_checkpoints_transport.dart';

/// A chat transport that owns runtimes and answers the checkpoint and
/// context calls from a [FakeCheckpointsTransport], for tests that drive the
/// Activity panel's Context and File checkpoints rows through a real
/// `ChatController`.
class ActionsChatTransport extends FakeChatTransport
    implements OwnedSessionTransport, CheckpointsTransport, ContextTransport {
  final fake = FakeCheckpointsTransport();
  final owned = <String, OwnedSessionBinding>{};

  /// The owned-session reads, by method.
  final reads = <String>[];
  Map<String, Object?> usage = const {
    'total': 10,
    'context_used': 1000,
    'context_max': 10000,
    'context_percent': 10,
  };
  final _changes = StreamController<OwnedSessionChange>.broadcast(sync: true);

  OwnedSessionBinding own(String thread, {String runtime = 'rt-1'}) {
    final binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: runtime,
      profile: 'work',
    );
    owned[thread] = binding;
    _changes.add(OwnedSessionChange(thread, binding));
    return binding;
  }

  void lose(String thread, {bool retired = false}) {
    final binding = owned[thread]!;
    if (retired) owned.remove(thread);
    _changes.add(
      OwnedSessionChange(thread, binding, connected: false, retired: retired),
    );
  }

  /// Reports [percent] of a 200,000 token window as the chat's usage.
  void reportUsage(String thread, int percent) {
    final binding = owned[thread]!;
    followUpStreams[thread]!.emit(
      SessionUsageUpdated(
        UsageSnapshot.decode({
          'context_used': 2000 * percent,
          'context_max': 200000,
          'context_percent': percent,
        }),
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
  }

  @override
  Stream<OwnedSessionChange> get ownedSessions => _changes.stream;

  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      profile == 'work' ? owned[threadId] : null;

  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async {
    reads.add(method);
    return usage;
  }

  @override
  Future<CheckpointList> listCheckpoints(OwnedSessionBinding binding) =>
      fake.listCheckpoints(binding);

  @override
  Future<CheckpointList> listCheckpointsResuming(
    String threadId, {
    String? profile,
  }) => fake.listCheckpointsResuming(threadId, profile: profile);

  @override
  Future<CheckpointChanges> checkpointChanges(
    OwnedSessionBinding binding,
    String hash,
  ) => fake.checkpointChanges(binding, hash);

  @override
  Future<CheckpointRestore> restoreCheckpoint(
    String threadId, {
    String? profile,
    required String hash,
    String? filePath,
  }) => fake.restoreCheckpoint(
    threadId,
    profile: profile,
    hash: hash,
    filePath: filePath,
  );

  @override
  Future<ContextBreakdown> contextBreakdown(OwnedSessionBinding binding) =>
      fake.contextBreakdown(binding);

  @override
  Future<CompressionResult> compressSession(
    String threadId, {
    String? profile,
    String? focus,
  }) => fake.compressSession(threadId, profile: profile, focus: focus);

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }
}
