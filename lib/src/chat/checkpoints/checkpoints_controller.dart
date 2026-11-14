import 'dart:async';

import 'package:flutter/foundation.dart';

import 'action_telemetry.dart';
import 'chat_action_bridge.dart';
import 'checkpoint_models.dart';
import 'checkpoints_state.dart';
import 'checkpoints_transport.dart';

export 'checkpoints_state.dart';

/// A restore the user started and has not confirmed. It fixes the chat, the
/// checkpoint and the file it was started for, and is good for one
/// confirmation.
class RestoreIntent {
  RestoreIntent._({
    required this.scope,
    required this.hash,
    required this.filePath,
    required this.quote,
    required this.agentWorking,
    required this.filesDiffer,
    required this.epoch,
    required this.turnEpoch,
  });

  final ActionScope scope;
  final String hash;

  /// Null restores every file (and rewinds the chat's last turn).
  final String? filePath;

  /// The message a full restore will take out of the chat, for the
  /// confirmation to quote and the composer to get back.
  final PromptQuote? quote;

  /// A one-file restore while a reply runs: the confirmation adds a warning.
  final bool agentWorking;

  /// How many files differ, when read from this checkpoint's changes since
  /// the last turn ended; null reads "some".
  final int? filesDiffer;
  final int epoch, turnEpoch;
  var _used = false;

  bool get isFull => filePath == null;
}

class _OpenChanges {
  _OpenChanges(this.hash, this.epoch);
  final String hash;
  final int epoch;
  CheckpointChanges? result;
}

/// The File checkpoints row, list, changes and restore for one chat.
class CheckpointsController extends ChangeNotifier {
  CheckpointsController({
    required this.transport,
    required this.bridge,
    this.telemetry = const ActionTelemetry(),
  });

  final CheckpointsTransport? transport;
  final ChatActionBridge bridge;
  final ActionTelemetry telemetry;

  ActionScope? _scope;
  int _epoch = 0, _listGeneration = 0, _changesGeneration = 0;

  /// Bumped only by [clear] and [dispose]: a restore that settles after one
  /// of them touches neither the chat nor this controller.
  int _clearEpoch = 0;

  /// Counts turns that ended, so a file count read before the last turn is
  /// not trusted.
  int _turnEpoch = 0;
  bool _connected = true, _locked = false, _disposed = false;
  bool _panelOpen = false, _loadingList = false;
  CheckpointList? _list;
  int? _lockedCount;
  final _readFailures = FailureStreak();

  _OpenChanges? _changes;
  bool _loadingChanges = false;

  bool _restoring = false, _sendHeld = false;
  RestoreIntent? _intent;
  RestoreOutcome? _outcome;

  // -- what the row and pages show -------------------------------------------

  CheckpointsRowState get rowState {
    final scope = _scope;
    if (scope == null || transport == null) return CheckpointsRowState.hidden;
    return switch (_list) {
      CheckpointsOn() => CheckpointsRowState.count,
      CheckpointsOff() =>
        bridge.hasEditToolCall()
            ? CheckpointsRowState.off
            : CheckpointsRowState.hidden,
      CheckpointsUnsupported() => CheckpointsRowState.hidden,
      CheckpointsFailed() => CheckpointsRowState.failed,
      null =>
        _loadingList
            ? CheckpointsRowState.loading
            : scope.binding == null
            ? CheckpointsRowState.notChecked
            : CheckpointsRowState.hidden,
    };
  }

  /// Newest first. Empty under App Lock, which shows only [count].
  List<Checkpoint> get checkpoints => switch (_list) {
    CheckpointsOn(:final checkpoints) when !_locked => checkpoints,
    _ => const [],
  };

  /// What the row counts, also under App Lock.
  int? get count => _locked
      ? _lockedCount
      : switch (_list) {
          CheckpointsOn(:final checkpoints) => checkpoints.length,
          _ => null,
        };

  bool get loadingList => _loadingList;
  bool get panelOpen => _panelOpen;
  bool get notUpToDate => !_connected;
  bool get locked => _locked;

  /// The container-backend refusal or another failure of the last read.
  CheckpointFailureKind? get listFailure => switch (_list) {
    CheckpointsFailed(:final kind) => kind,
    _ => null,
  };

  /// The changes of the checkpoint the user opened, held in memory only.
  CheckpointChanges? get changes => _locked ? null : _changes?.result;
  String? get openHash => _locked ? null : _changes?.hash;
  bool get loadingChanges => _loadingChanges;

  bool get restoring => _restoring;

  /// Send is disabled and the send queue held: from the confirmation of a
  /// full restore until it settles.
  bool get sendHeld => _sendHeld;
  RestoreOutcome? get outcome => _outcome;

  // -- binding ---------------------------------------------------------------

  void bind(ActionScope? scope) {
    if (_disposed || scope == _scope) return;
    final previous = _scope;
    final resumed =
        previous != null &&
        previous.binding == null &&
        scope != null &&
        scope.binding != null &&
        previous.threadId == scope.threadId;
    _scope = scope;
    _epoch++;
    _listGeneration++;
    _changesGeneration++;
    _list = null;
    _loadingList = false;
    _changes = null;
    _loadingChanges = false;
    _intent = null;
    _connected = true;
    _readFailures.clear();
    _notify();
    // A chat that gets its runtime while the panel is open (it was resumed
    // to be listed) is listed for that runtime.
    if (_panelOpen && resumed) unawaited(refresh());
  }

  void setLocked(bool locked) {
    if (_disposed || locked == _locked) return;
    final shown = count;
    _locked = locked;
    if (locked) {
      _lockedCount = shown;
      _changesGeneration++;
      _changes = null;
      _loadingChanges = false;
      _intent = null;
    } else {
      _lockedCount = null;
    }
    _notify();
  }

  void disconnected() {
    if (_disposed || !_connected) return;
    _connected = false;
    _listGeneration++;
    _changesGeneration++;
    _loadingList = false;
    _loadingChanges = false;
    _intent = null;
    _notify();
  }

  Future<void> reconnected() async {
    if (_disposed || _connected) return;
    _connected = true;
    _notify();
    if (_panelOpen) await refresh();
  }

  /// Sign-out, profile switch or close: nothing is kept.
  void clear() {
    if (_disposed) return;
    _scope = null;
    _epoch++;
    _clearEpoch++;
    _listGeneration++;
    _changesGeneration++;
    _list = null;
    _lockedCount = null;
    _changes = null;
    _loadingList = false;
    _loadingChanges = false;
    _panelOpen = false;
    _intent = null;
    _outcome = null;
    _notify();
  }

  // -- reads -----------------------------------------------------------------

  /// The Activity panel opened. A chat with a live session lists now; a
  /// stored chat without one waits for [openResuming].
  Future<void> panelOpened() async {
    if (_disposed) return;
    _panelOpen = true;
    telemetry.crumb('chat.checkpoints.opened');
    if (_scope?.binding != null) await refresh();
    _notify();
  }

  void panelClosed() {
    if (_disposed) return;
    _panelOpen = false;
    closeChanges();
  }

  /// The user tapped the row of a stored chat that has no live session:
  /// this resumes it, as sending would, and lists.
  Future<void> openResuming() async {
    final scope = _scope, source = transport;
    if (_disposed ||
        _locked ||
        !_connected ||
        scope == null ||
        source == null) {
      return;
    }
    if (scope.binding != null) return refresh();
    await _load(
      () => source.listCheckpointsResuming(
        scope.threadId,
        profile: scope.profile,
      ),
    );
  }

  /// A turn ended: the list is read again only while the panel is open, and
  /// a file count read before it is no longer trusted.
  Future<void> turnEnded() async {
    _turnEpoch++;
    if (_panelOpen) await refresh();
  }

  /// Reads the list for the live session. Never on a timer.
  Future<void> refresh() async {
    final binding = _scope?.binding, source = transport;
    if (_disposed ||
        _locked ||
        !_connected ||
        binding == null ||
        source == null) {
      return;
    }
    await _load(() => source.listCheckpoints(binding));
  }

  Future<void> _load(Future<CheckpointList> Function() read) async {
    final generation = ++_listGeneration;
    final epoch = _epoch;
    _loadingList = true;
    _notify();
    final span = telemetry.start('chat.checkpoints.list');
    CheckpointList result;
    try {
      result = await read();
    } on Object {
      result = const CheckpointsFailed(CheckpointFailureKind.transport);
    }
    telemetry.finish(span, {
      'outcome': switch (result) {
        CheckpointsOn() => 'ok',
        CheckpointsOff() => 'off',
        CheckpointsUnsupported() => 'unsupported',
        CheckpointsFailed() => 'failed',
      },
      if (result is CheckpointsOn)
        'count': ActionTelemetry.bucket(result.checkpoints.length),
    });
    // A late answer for another scope, thread or connection is dropped.
    if (_disposed || generation != _listGeneration || epoch != _epoch) return;
    _loadingList = false;
    _list = result;
    if (result is CheckpointsFailed) {
      if (_readFailures.note()) {
        telemetry.event('chat.checkpoints.read_failed', {
          'kind': result.kind.name,
        });
      }
    } else {
      _readFailures.clear();
    }
    _notify();
  }

  /// Reads the diff of one checkpoint, only when the user opens it.
  Future<void> openChanges(String hash) async {
    final binding = _scope?.binding, source = transport;
    if (_disposed ||
        _locked ||
        !_connected ||
        binding == null ||
        source == null) {
      return;
    }
    final generation = ++_changesGeneration;
    final epoch = _epoch;
    final open = _changes = _OpenChanges(hash, _turnEpoch);
    _loadingChanges = true;
    _notify();
    final span = telemetry.start('chat.checkpoints.diff');
    CheckpointChanges result;
    try {
      result = await source.checkpointChanges(binding, hash);
    } on Object {
      result = const ChangesFailed(CheckpointFailureKind.transport);
    }
    telemetry.finish(span, {
      'outcome': switch (result) {
        Changes() => 'ok',
        ChangesUnreadable() => 'unreadable',
        ChangesRefused() => 'refused',
        ChangesFailed() => 'failed',
      },
      if (result is Changes) ...{
        'files': ActionTelemetry.bucket(result.files.length),
        'truncated': result.truncated,
      },
    });
    if (_disposed || generation != _changesGeneration || epoch != _epoch) {
      return;
    }
    _loadingChanges = false;
    open.result = result;
    _notify();
  }

  /// Leaves the Changes page: the diff text is dropped.
  void closeChanges() {
    if (_disposed || _changes == null) return;
    _changesGeneration++;
    _changes = null;
    _loadingChanges = false;
    _notify();
  }

  // -- restore ---------------------------------------------------------------

  RestoreRefusal? restoreRefusal({String? filePath}) {
    if (transport == null || _scope?.binding == null) {
      return RestoreRefusal.unavailable;
    }
    if (_locked) return RestoreRefusal.locked;
    if (!_connected) return RestoreRefusal.disconnected;
    if (_restoring) return RestoreRefusal.restoring;
    if (filePath == null && bridge.isReplying()) return RestoreRefusal.replying;
    return null;
  }

  /// Starts a restore of [hash] (a full hash from the list) for the user to
  /// confirm: every file when [filePath] is null, otherwise that one file,
  /// which must be a restorable path read from this checkpoint's `stat`.
  /// Returns null, and sends nothing, while [restoreRefusal] says no.
  RestoreIntent? beginRestore(String hash, {String? filePath}) {
    final scope = _scope;
    if (_disposed ||
        scope == null ||
        restoreRefusal(filePath: filePath) != null ||
        !checkpoints.any((c) => c.hash == hash)) {
      return null;
    }
    final open = _changes;
    final known = open != null && open.hash == hash ? open.result : null;
    if (filePath != null) {
      final offered =
          known is Changes &&
          known.files.any((f) => f.path == filePath && f.restorable);
      if (!offered) return null;
    }
    // A count counts only when read since the last turn ended.
    final trusted = known is Changes && open!.epoch == _turnEpoch;
    return _intent = RestoreIntent._(
      scope: scope,
      hash: hash,
      filePath: filePath,
      quote: filePath == null ? bridge.lastPrompt() : null,
      agentWorking: filePath != null && bridge.isReplying(),
      filesDiffer: trusted ? known.files.length : null,
      epoch: _epoch,
      turnEpoch: _turnEpoch,
    );
  }

  /// Sends the restore the user confirmed, for the chat, checkpoint and file
  /// it was started with. Sent once: a lost answer re-lists and re-reads the
  /// chat, and offering it again takes a new confirmation.
  Future<void> confirmRestore(RestoreIntent intent) async {
    final source = transport;
    if (_disposed ||
        source == null ||
        intent._used ||
        !identical(intent, _intent) ||
        intent.epoch != _epoch ||
        intent.scope != _scope) {
      return;
    }
    final refusal = restoreRefusal(filePath: intent.filePath);
    if (refusal != null) {
      // A reply started while the confirmation was open: nothing is sent.
      if (refusal == RestoreRefusal.replying) {
        _outcome = const RestoreOutcome(RestoreOutcomeKind.busyReplying);
        _intent = null;
        _notify();
      }
      return;
    }
    intent._used = true;
    _intent = null;
    _restoring = true;
    _outcome = null;
    if (intent.isFull) _setSendHeld(true);
    _notify();
    telemetry.crumb('chat.checkpoints.restore_confirmed', {
      'scope': intent.isFull ? 'all' : 'file',
    });
    final before = {for (final c in checkpoints) c.hash};
    final clearEpoch = _clearEpoch;
    bool live() => !_disposed && clearEpoch == _clearEpoch;
    final span = telemetry.start('chat.checkpoints.restore');
    CheckpointRestore result;
    try {
      result = await source.restoreCheckpoint(
        intent.scope.threadId,
        profile: intent.scope.profile,
        hash: intent.hash,
        filePath: intent.filePath,
      );
    } on Object {
      result = const RestoreMayHaveHappened();
    }
    try {
      final outcome = await _settle(intent, result, before, live);
      telemetry.finish(span, {
        'scope': intent.isFull ? 'all' : 'file',
        'outcome': outcome.kind.name,
        'history_removed': ActionTelemetry.bucket(outcome.historyRemoved),
      });
      if (live()) _outcome = outcome;
    } finally {
      _restoring = false;
      // Send is held until the restore settles: success, failure or a lost
      // answer.
      if (intent.isFull) _setSendHeld(false);
      _notify();
    }
  }

  /// Turns [result] into an outcome. While [live] says this controller was
  /// not cleared or disposed meanwhile, it also re-reads the list and the
  /// chat; otherwise it touches neither (a sign-out keeps nothing, and the
  /// old prompt never reaches a composer).
  Future<RestoreOutcome> _settle(
    RestoreIntent intent,
    CheckpointRestore result,
    Set<String> before,
    bool Function() live,
  ) async {
    Future<bool> relist() async => live() && await _relist();
    Future<bool> refetch() async => live() && await _refetchChat();

    switch (result) {
      case Restored(:final historyRemoved):
        final listed = await relist();
        // After one file the Changes page comes back, re-read, if it is
        // still showing and the checkpoint is still listed.
        if (!intent.isFull &&
            listed &&
            live() &&
            _panelOpen &&
            checkpoints.any((c) => c.hash == intent.hash)) {
          await openChanges(intent.hash);
        }
        final refetched = await refetch();
        final added = listed && live()
            ? _addedSafetyCheckpoint(intent.hash, before)
            : null;
        var notRemoved = false;
        final quote = intent.quote;
        // Only a re-read chat can say whether the quoted message is gone.
        if (intent.isFull &&
            historyRemoved > 0 &&
            quote != null &&
            refetched &&
            live()) {
          if (_chatHolds(quote)) {
            notRemoved = true;
          } else {
            bridge.handBackToComposer(quote.text);
          }
        }
        // N counts only when read since the last turn ended, checked now.
        final trusted = intent.turnEpoch == _turnEpoch;
        return RestoreOutcome(
          RestoreOutcomeKind.restored,
          filesRestored: intent.isFull
              ? (trusted ? intent.filesDiffer : null)
              : 1,
          historyRemoved: historyRemoved,
          safetyCheckpoint: added,
          lastMessageNotRemoved: notRemoved,
        );
      case RestoredHistoryNotRewound():
        await relist();
        await refetch();
        return const RestoreOutcome(RestoreOutcomeKind.historyNotRewound);
      case RestoreRefused(:final kind):
        if (kind == CheckpointFailureKind.notFound) await relist();
        return RestoreOutcome(RestoreOutcomeKind.refused, refusal: kind);
      case RestoreBusy(:final reason):
        return RestoreOutcome(
          reason == CheckpointBusyReason.compressing
              ? RestoreOutcomeKind.busyCompressing
              : RestoreOutcomeKind.busyReplying,
        );
      case RestoreMayHaveHappened():
        await relist();
        await refetch();
        return const RestoreOutcome(RestoreOutcomeKind.mayHaveHappened);
      case RestoreUnsupported():
        return const RestoreOutcome(RestoreOutcomeKind.unsupported);
      case RestoreFailed(:final kind, :final filesPossiblyChanged):
        if (kind == CheckpointFailureKind.sessionGone) {
          if (live()) {
            try {
              await bridge.reestablishSession();
            } on Object {
              // The user is asked to try again either way.
            }
          }
          return const RestoreOutcome(RestoreOutcomeKind.sessionGone);
        }
        if (filesPossiblyChanged) {
          await relist();
          await refetch();
        }
        return RestoreOutcome(
          filesPossiblyChanged
              ? RestoreOutcomeKind.failedMaybeChanged
              : RestoreOutcomeKind.failedNothingChanged,
          refusal: kind,
        );
    }
  }

  bool _chatHolds(PromptQuote quote) {
    try {
      return bridge.chatHolds(quote);
    } on Object {
      // Unknown: leave the composer alone.
      return true;
    }
  }

  /// A new hash, absent before the restore, whose reason is a safety
  /// checkpoint "restoring to" the first eight characters of the restored
  /// hash. An older "Before a restore" row at the top does not count. Null
  /// (unknown) under App Lock, which hides the list.
  bool? _addedSafetyCheckpoint(String restored, Set<String> before) {
    if (_locked) return null;
    final list = _list;
    if (list is! CheckpointsOn) return null;
    final prefix = restored.toLowerCase();
    return list.checkpoints.any(
      (c) =>
          !before.contains(c.hash) &&
          c.reason == CheckpointReason.beforeRestore &&
          c.restoredFrom != null &&
          prefix.startsWith(c.restoredFrom!.toLowerCase()),
    );
  }

  /// Re-reads the list; false when it was not read. Under App Lock or while
  /// disconnected the kept list is left alone.
  Future<bool> _relist() async {
    final binding = _scope?.binding, source = transport;
    if (_disposed ||
        _locked ||
        !_connected ||
        binding == null ||
        source == null) {
      return false;
    }
    // The diff of a restored checkpoint is stale.
    _changesGeneration++;
    _changes = null;
    _loadingChanges = false;
    await _load(() => source.listCheckpoints(binding));
    return _list is CheckpointsOn;
  }

  /// Re-reads the chat; false when that failed.
  Future<bool> _refetchChat() async {
    try {
      await bridge.refetchChat();
      return true;
    } on Object {
      return false;
    }
  }

  void _setSendHeld(bool held) {
    if (_sendHeld == held) return;
    _sendHeld = held;
    try {
      bridge.holdSend(held);
    } on Object {
      // The hold is also exposed as [sendHeld].
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    if (_sendHeld) _setSendHeld(false);
    _disposed = true;
    _epoch++;
    _clearEpoch++;
    _listGeneration++;
    _changesGeneration++;
    _list = null;
    _changes = null;
    super.dispose();
  }
}
