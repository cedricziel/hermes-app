part of 'hermes_gateway_transport.dart';

/// `rollback.*`, `session.context_breakdown` and `session.compress`.
extension _Checkpoints on HermesGatewayTransport {
  Future<Map<String, Object?>> _readBound(
    OwnedSessionBinding binding,
    String method,
    Map<String, Object?> params,
    Duration timeout,
  ) async {
    if (!_ownsBinding(binding)) throw const GatewayConnectionClosed();
    final client = binding.connection as GatewayRpcClient;
    final result = await client.requestWithin(method, {
      'session_id': binding.runtimeId,
      'profile': ?binding.profile,
      ...params,
    }, timeout: timeout);
    if (!_ownsBinding(binding)) throw const GatewayConnectionClosed();
    return result;
  }

  /// A failure that says nothing about whether anything happened.
  CheckpointFailureKind _failureKind(Object error) {
    if (error is GatewayRpcException) {
      if (error.code == 4001) return CheckpointFailureKind.sessionGone;
      if (isContainerRefusal(error.message)) {
        return CheckpointFailureKind.container;
      }
    }
    return error is GatewayRpcException
        ? CheckpointFailureKind.other
        : CheckpointFailureKind.transport;
  }

  /// A reply in progress also names `/compress` ("…then run /compress."), so
  /// only the server's "a /compress is running" wording means compressing.
  CheckpointBusyReason _busyReason(GatewayRpcException error) =>
      error.message.toLowerCase().contains('a /compress is running')
      ? CheckpointBusyReason.compressing
      : CheckpointBusyReason.replying;

  Future<CheckpointList> _listCheckpointsOn(
    Future<Map<String, Object?>> Function() read,
  ) async {
    try {
      return parseCheckpointList(await read()) ??
          const CheckpointsFailed(CheckpointFailureKind.other);
    } on GatewayRpcException catch (error) {
      return error.code == kGatewayMethodNotFound
          ? const CheckpointsUnsupported()
          : CheckpointsFailed(_failureKind(error));
    } on Object catch (error) {
      return CheckpointsFailed(_failureKind(error));
    }
  }

  Future<CheckpointList> _listCheckpoints(OwnedSessionBinding binding) =>
      _listCheckpointsOn(
        () => _readBound(binding, 'rollback.list', const {}, readTimeout),
      );

  Future<CheckpointList> _listCheckpointsResuming(
    String threadId,
    String? profile,
  ) => _listCheckpointsOn(() async {
    final client = await _client();
    final runtimeId = await _commandRuntime(client, threadId, profile);
    return client.requestWithin('rollback.list', {
      'session_id': runtimeId,
      'profile': ?profile,
    }, timeout: readTimeout);
  });

  Future<CheckpointChanges> _checkpointChanges(
    OwnedSessionBinding binding,
    String hash,
  ) async {
    if (!isUsableCheckpointHash(hash)) {
      return const ChangesFailed(CheckpointFailureKind.notFound);
    }
    try {
      return parseCheckpointChanges(
        await _readBound(binding, 'rollback.diff', {'hash': hash}, longTimeout),
      );
    } on GatewayRpcException catch (error) {
      if (isContainerRefusal(error.message)) return const ChangesRefused();
      return ChangesFailed(_failureKind(error));
    } on Object catch (error) {
      return ChangesFailed(_failureKind(error));
    }
  }

  Future<CheckpointRestore> _restoreCheckpoint(
    String threadId,
    String? profile,
    String hash,
    String? filePath,
  ) async {
    if (!isUsableCheckpointHash(hash)) {
      return const RestoreRefused(CheckpointFailureKind.notFound);
    }
    final Map<String, Object?> result;
    final GatewayRpcClient client;
    final String runtimeId;
    try {
      client = await _client();
      runtimeId = await _commandRuntime(client, threadId, profile);
    } on Object catch (error) {
      if (error is GatewayRpcException &&
          error.code == kGatewayMethodNotFound) {
        return const RestoreUnsupported();
      }
      // Nothing was sent: the files were not touched.
      return RestoreFailed(_failureKind(error), filesPossiblyChanged: false);
    }
    try {
      // Sent once. A lost answer is never a reason to send it again.
      result = await client.requestWithin('rollback.restore', {
        'session_id': runtimeId,
        'profile': ?profile,
        'hash': hash,
        'file_path': ?filePath,
      }, timeout: longTimeout);
    } on GatewayRpcException catch (error) {
      return _restoreError(error);
    } on Object {
      return const RestoreMayHaveHappened();
    }
    return _readRestore(result);
  }

  CheckpointRestore _restoreError(GatewayRpcException error) {
    if (error.code == kGatewayMethodNotFound) {
      return const RestoreUnsupported();
    }
    if (error.code == 4009) return RestoreBusy(_busyReason(error));
    if (error.code == 5021) {
      return error.message.startsWith(
            'checkpoint restored, but session history rewind failed',
          )
          ? const RestoredHistoryNotRewound()
          : const RestoreFailed(
              CheckpointFailureKind.other,
              filesPossiblyChanged: true,
            );
    }
    final kind = _failureKind(error);
    return kind == CheckpointFailureKind.container
        ? const RestoreRefused(CheckpointFailureKind.container)
        : RestoreFailed(
            kind,
            filesPossiblyChanged:
                kind == CheckpointFailureKind.other &&
                error.code != 4014 &&
                error.code != 5022,
          );
  }

  CheckpointRestore _readRestore(Map<String, Object?> result) {
    if (result['success'] == true) {
      final removed = result['history_removed'];
      return Restored(
        historyRemoved: removed is int && removed > 0 && removed <= 10000000
            ? removed
            : 0,
      );
    }
    final error = result['error'];
    if (result['success'] != false || error is! String) {
      return const RestoreFailed(
        CheckpointFailureKind.other,
        filesPossiblyChanged: true,
      );
    }
    // Only a refusal answered before the safety checkpoint says nothing
    // changed; everything else may have touched files.
    if (isContainerRefusal(error)) {
      return const RestoreRefused(CheckpointFailureKind.container);
    }
    if (error.startsWith('Checkpoint contains nested git repositories')) {
      return const RestoreRefused(CheckpointFailureKind.nestedRepositories);
    }
    if (error.startsWith('No checkpoints exist') ||
        RegExp(r"^Checkpoint '.*' not found").hasMatch(error)) {
      return const RestoreRefused(CheckpointFailureKind.notFound);
    }
    if (error.startsWith('File path escapes') ||
        error.startsWith('File path must be relative') ||
        error.startsWith('Restore selection matched no files')) {
      return const RestoreRefused(CheckpointFailureKind.pathRejected);
    }
    if (error.startsWith('checkpoint store is busy')) {
      return const RestoreFailed(
        CheckpointFailureKind.storeBusy,
        filesPossiblyChanged: true,
      );
    }
    return const RestoreFailed(
      CheckpointFailureKind.other,
      filesPossiblyChanged: true,
    );
  }

  Future<ContextBreakdown> _contextBreakdown(
    OwnedSessionBinding binding,
  ) async {
    try {
      return parseBreakdown(
        await _readBound(
          binding,
          'session.context_breakdown',
          const {},
          readTimeout,
        ),
      );
    } on GatewayRpcException catch (error) {
      return error.code == kGatewayMethodNotFound
          ? const BreakdownUnsupported()
          : BreakdownFailed(_failureKind(error));
    } on Object catch (error) {
      return BreakdownFailed(_failureKind(error));
    }
  }

  Future<CompressionResult> _compressSession(
    String threadId,
    String? profile,
    String? focus,
  ) async {
    final topic = focus?.trim();
    if (topic != null && !isAcceptableFocus(topic)) {
      throw ArgumentError('focus would be read as a command');
    }
    final GatewayRpcClient client;
    final String runtimeId;
    try {
      client = await _client();
      runtimeId = await _commandRuntime(client, threadId, profile);
    } on Object catch (error) {
      if (error is GatewayRpcException &&
          error.code == kGatewayMethodNotFound) {
        return const CompressUnsupported();
      }
      return CompressFailed(_failureKind(error));
    }
    try {
      return parseCompression(
        await client.requestWithin('session.compress', {
          'session_id': runtimeId,
          'profile': ?profile,
          if (topic != null && topic.isNotEmpty) 'focus_topic': topic,
        }, timeout: longTimeout),
      );
    } on GatewayRpcException catch (error) {
      return switch (error.code) {
        kGatewayMethodNotFound => const CompressUnsupported(),
        4009 => CompressBusy(_busyReason(error)),
        _ => CompressFailed(_failureKind(error)),
      };
    } on Object {
      return const CompressMayHaveHappened();
    }
  }
}
