import 'package:flutter/foundation.dart';

import '../checkpoints/action_telemetry.dart';
import '../checkpoints/chat_action_bridge.dart';
import '../checkpoints/checkpoint_models.dart'
    show CheckpointBusyReason, CheckpointFailureKind;
import '../checkpoints/checkpoints_transport.dart';
import '../session_usage/usage_snapshot.dart';
import 'context_models.dart';

/// How full the window is, for the row's wording and emphasis.
enum ContextLevel { normal, nearlyFull, critical, full }

/// Why a compress cannot start now.
enum CompressRefusal {
  /// Nothing confirmed a live session for this chat, or the server has no
  /// `session.compress`.
  unavailable,
  disconnected,
  locked,
  replying,
  compressing,
}

enum CompressOutcomeKind {
  compressed,
  nothingToCompress,
  wouldNotShrink,
  aborted,
  busyReplying,
  busyCompressing,
  lockHeld,
  pending,

  /// No answer, or the connection dropped. The chat and usage were re-read;
  /// the action is offered again behind a new confirmation.
  couldntConfirm,
  failed,
  unsupported,
}

class CompressOutcome {
  const CompressOutcome(
    this.kind, {
    this.beforeMessages,
    this.afterMessages,
    this.beforeTokens,
    this.afterTokens,
    this.fallbackUsed = false,
  });

  final CompressOutcomeKind kind;
  final int? beforeMessages, afterMessages, beforeTokens, afterTokens;
  final bool fallbackUsed;
}

/// A compress the user has started and not yet confirmed. It fixes the chat
/// it was started for and is good for one confirmation: if the scope changed
/// since, or it was used, confirming does nothing.
class CompressIntent {
  CompressIntent._(this._scope, this._epoch);
  final ActionScope _scope;
  final int _epoch;
  var _used = false;
}

/// The figures the Context row shows, straight from the usage snapshot.
/// Anything the server did not report is null, never zero.
class ContextFigures {
  const ContextFigures({
    required this.used,
    required this.max,
    required this.percent,
    required this.estimated,
    required this.source,
  });
  final int used, max, percent;
  final bool? estimated;
  final ContextSource? source;
}

/// The Context row, its details and compress, for one chat. It reads the
/// usage snapshot the Session usage card holds and starts no poll of its own.
class ContextController extends ChangeNotifier {
  ContextController({
    required this.transport,
    required this.bridge,
    this.telemetry = const ActionTelemetry(),
  });

  final ContextTransport? transport;
  final ChatActionBridge bridge;
  final ActionTelemetry telemetry;

  ActionScope? _scope;
  int _epoch = 0, _breakdownGeneration = 0;
  UsageSnapshot? _usage;
  bool _connected = true, _locked = false, _disposed = false;
  bool _detailsOpen = false;

  Breakdown? _breakdown;
  bool _breakdownLoading = false, _breakdownFailed = false;
  bool _breakdownSupported = true, _compressSupported = true;
  final _readFailures = FailureStreak();

  bool _compressing = false, _pendingRemote = false;
  CompressIntent? _intent;
  CompressOutcome? _outcome;

  bool _dismissed = false, _suggestionReported = false;

  // -- what the row shows ---------------------------------------------------

  /// The Context row exists only when the server reported all three figures.
  ContextFigures? get figures {
    final usage = _usage;
    final used = usage?.contextUsed,
        max = usage?.contextMax,
        percent = usage?.contextPercent;
    if (_scope == null || used == null || max == null || percent == null) {
      return null;
    }
    return ContextFigures(
      used: used,
      max: max,
      percent: percent > 100 ? 100 : percent,
      estimated: usage?.contextEstimated,
      source: usage?.contextSource,
    );
  }

  bool get hasRow => figures != null;

  ContextLevel get level {
    final f = figures;
    if (f == null) return ContextLevel.normal;
    if (f.percent >= 100 || f.used > f.max) return ContextLevel.full;
    if (f.percent >= 95) return ContextLevel.critical;
    if (f.percent >= 80) return ContextLevel.nearlyFull;
    return ContextLevel.normal;
  }

  /// The values are the last known ones and actions are off.
  bool get notUpToDate => !_connected;

  /// App Lock: only the percentage may be drawn.
  bool get locked => _locked;

  bool get detailsOpen => _detailsOpen;

  /// The categories, null until read, and after a failure, App Lock or a
  /// scope change.
  Breakdown? get breakdown => _locked ? null : _breakdown;
  bool get breakdownLoading => _breakdownLoading;
  bool get breakdownFailed => _breakdownFailed;

  /// False once the server said it has no breakdown: details show the total
  /// and Compress only, with no error.
  bool get breakdownSupported => _breakdownSupported;

  bool get compressSupported => _compressSupported && transport != null;
  bool get compressing => _compressing || _pendingRemote;
  CompressOutcome? get outcome => _outcome;

  bool get suggestionVisible {
    final f = figures;
    if (f == null || _dismissed || compressRefusal != null) return false;
    if (f.percent < 85) return false;
    // A local guess does not earn a prompt below 95.
    if (f.source == ContextSource.localEstimate && f.percent < 95) {
      return false;
    }
    return true;
  }

  CompressRefusal? get compressRefusal {
    if (!compressSupported || _scope?.binding == null) {
      return CompressRefusal.unavailable;
    }
    if (_locked) return CompressRefusal.locked;
    if (!_connected) return CompressRefusal.disconnected;
    if (compressing) return CompressRefusal.compressing;
    if (bridge.isReplying()) return CompressRefusal.replying;
    return null;
  }

  bool get canCompress => compressRefusal == null;

  // -- binding --------------------------------------------------------------

  /// Binds to [scope]; any change drops what was read for the old one.
  void bind(ActionScope? scope) {
    if (_disposed || scope == _scope) return;
    _scope = scope;
    _epoch++;
    _breakdownGeneration++;
    _breakdown = null;
    _breakdownLoading = false;
    _breakdownFailed = false;
    _breakdownSupported = true;
    _intent = null;
    _connected = true;
    _readFailures.clear();
    _notify();
  }

  /// The usage snapshot the Session usage card holds.
  void updateUsage(UsageSnapshot? usage) {
    if (_disposed) return;
    _usage = usage;
    final percent = usage?.contextPercent;
    if (percent != null && percent < 60) {
      _dismissed = false;
      _suggestionReported = false;
    }
    _notify();
  }

  void setLocked(bool locked) {
    if (_disposed || locked == _locked) return;
    _locked = locked;
    if (locked) {
      _breakdownGeneration++;
      _breakdown = null;
      _breakdownLoading = false;
      _detailsOpen = false;
      _intent = null;
    }
    _notify();
  }

  void disconnected() {
    if (_disposed || !_connected) return;
    _connected = false;
    _breakdownGeneration++;
    _breakdownLoading = false;
    _intent = null;
    _notify();
  }

  Future<void> reconnected() async {
    if (_disposed || _connected) return;
    _connected = true;
    _notify();
    await _readBreakdownIfOpen();
  }

  /// Sign-out, profile switch or close: nothing is kept.
  void clear() {
    if (_disposed) return;
    _scope = null;
    _epoch++;
    _breakdownGeneration++;
    _usage = null;
    _breakdown = null;
    _breakdownLoading = false;
    _breakdownFailed = false;
    _detailsOpen = false;
    _intent = null;
    _outcome = null;
    _dismissed = false;
    _suggestionReported = false;
    _notify();
  }

  // -- reads ----------------------------------------------------------------

  Future<void> openDetails({String from = 'row'}) async {
    if (_disposed || _locked) return;
    telemetry.crumb('chat.context.opened', {'from': from});
    if (from == 'suggestion') {
      telemetry.crumb('chat.context.suggestion', {'action': 'accepted'});
    }
    _detailsOpen = true;
    _notify();
    await _readBreakdown();
  }

  void closeDetails() {
    if (_disposed || !_detailsOpen) return;
    _detailsOpen = false;
    _breakdownGeneration++;
    _breakdown = null;
    _breakdownLoading = false;
    _notify();
  }

  /// A turn ended: the breakdown is read again, but only while the details
  /// are open.
  Future<void> turnEnded() => _readBreakdownIfOpen();

  /// Hermes compacted the conversation by itself: the usage is read again
  /// and, while the details are open, the breakdown too.
  Future<void> compacted() async {
    await _refreshUsage();
    await _readBreakdownIfOpen();
  }

  /// A compute-host compress reported it has settled.
  Future<void> sessionSettled() async {
    if (_disposed || !_pendingRemote) return;
    _pendingRemote = false;
    _notify();
    await _rereadAfterCompress();
  }

  Future<void> _readBreakdownIfOpen() async {
    if (_detailsOpen) await _readBreakdown();
  }

  Future<void> _readBreakdown() async {
    final scope = _scope, binding = scope?.binding, source = transport;
    if (_disposed ||
        _locked ||
        !_connected ||
        !_breakdownSupported ||
        binding == null ||
        source == null) {
      return;
    }
    final generation = ++_breakdownGeneration;
    final epoch = _epoch;
    _breakdownLoading = true;
    _breakdownFailed = false;
    _notify();
    final span = telemetry.start('chat.context.breakdown');
    ContextBreakdown result;
    try {
      result = await source.contextBreakdown(binding);
    } on Object {
      result = const BreakdownFailed(CheckpointFailureKind.transport);
    }
    final outcome = switch (result) {
      Breakdown() => 'ok',
      BreakdownUnsupported() => 'unsupported',
      BreakdownFailed() => 'failed',
    };
    telemetry.finish(span, {'outcome': outcome});
    // A late answer for another scope, a closed page or a lock is dropped.
    if (_disposed ||
        generation != _breakdownGeneration ||
        epoch != _epoch ||
        _locked) {
      return;
    }
    _breakdownLoading = false;
    switch (result) {
      case Breakdown():
        _breakdown = result;
        _breakdownFailed = false;
        _readFailures.clear();
      case BreakdownUnsupported():
        _breakdownSupported = false;
        _breakdown = null;
      case BreakdownFailed(:final kind):
        _breakdownFailed = true;
        if (_readFailures.note()) {
          telemetry.event('chat.context.read_failed', {'kind': kind.name});
        }
    }
    _notify();
  }

  // -- suggestion -----------------------------------------------------------

  /// Not now: the suggestion does not return until the context fell below
  /// 60% and filled again.
  void dismissSuggestion() {
    if (_disposed || _dismissed) return;
    _dismissed = true;
    telemetry.crumb('chat.context.suggestion', {'action': 'dismissed'});
    _notify();
  }

  // -- compress -------------------------------------------------------------

  /// Whether [focus] may be sent. False means the confirmation shows the
  /// focus error and Compress stays off.
  bool focusAcceptable(String focus) => isAcceptableFocus(focus);

  /// Starts a compress the user will confirm. Returns null, and sends
  /// nothing, while [compressRefusal] says no.
  CompressIntent? beginCompress() {
    final scope = _scope;
    if (_disposed || scope == null || compressRefusal != null) return null;
    return _intent = CompressIntent._(scope, _epoch);
  }

  /// Sends the compress the user confirmed, for the chat it was started in.
  /// Sent once; a lost answer re-reads and is never sent again.
  Future<void> confirmCompress(CompressIntent intent, {String? focus}) async {
    final source = transport;
    if (_disposed ||
        source == null ||
        intent._used ||
        !identical(intent, _intent) ||
        intent._epoch != _epoch ||
        intent._scope != _scope) {
      return;
    }
    final topic = focus?.trim();
    if (topic != null && !isAcceptableFocus(topic)) return;
    final refusal = compressRefusal;
    if (refusal != null) {
      // A reply started while the confirmation was open: nothing is sent.
      if (refusal == CompressRefusal.replying) {
        _outcome = const CompressOutcome(CompressOutcomeKind.busyReplying);
        _intent = null;
        _notify();
      }
      return;
    }
    intent._used = true;
    _intent = null;
    _compressing = true;
    _outcome = null;
    _notify();
    telemetry.crumb('chat.context.compress_confirmed');
    final span = telemetry.start('chat.context.compress');
    CompressionResult result;
    try {
      result = await source.compressSession(
        intent._scope.threadId,
        profile: intent._scope.profile,
        focus: topic == null || topic.isEmpty ? null : topic,
      );
    } on Object {
      result = const CompressMayHaveHappened();
    }
    final outcome = _outcomeOf(result);
    telemetry.finish(span, {
      'outcome': outcome.kind.name,
      'focused': topic != null && topic.isNotEmpty,
      'fallback_used': outcome.fallbackUsed,
      'source': 'manual',
      if (outcome.beforeMessages case final n?)
        'before': ActionTelemetry.bucket(n),
      if (outcome.afterMessages case final n?)
        'after': ActionTelemetry.bucket(n),
    });
    _compressing = false;
    if (_disposed) return;
    _outcome = outcome;
    if (result is CompressUnsupported) _compressSupported = false;
    if (result is CompressPending) _pendingRemote = true;
    if (result is Compressed) _dismissed = true;
    _notify();
    switch (result) {
      case Compressed() || CompressMayHaveHappened():
        await _rereadAfterCompress();
      case CompressLockHeld():
        await _refreshUsage();
      default:
        break;
    }
  }

  CompressOutcome _outcomeOf(CompressionResult result) => switch (result) {
    Compressed() => CompressOutcome(
      CompressOutcomeKind.compressed,
      beforeMessages: result.beforeMessages,
      afterMessages: result.afterMessages,
      beforeTokens: result.beforeTokens,
      afterTokens: result.afterTokens,
      fallbackUsed: result.fallbackUsed,
    ),
    NothingToCompress() => const CompressOutcome(
      CompressOutcomeKind.nothingToCompress,
    ),
    WouldNotShrink() => const CompressOutcome(
      CompressOutcomeKind.wouldNotShrink,
    ),
    CompressionAborted() => const CompressOutcome(CompressOutcomeKind.aborted),
    CompressBusy(:final reason) => CompressOutcome(
      reason == CheckpointBusyReason.compressing
          ? CompressOutcomeKind.busyCompressing
          : CompressOutcomeKind.busyReplying,
    ),
    CompressLockHeld() => const CompressOutcome(CompressOutcomeKind.lockHeld),
    CompressPending() => const CompressOutcome(CompressOutcomeKind.pending),
    CompressUnsupported() => const CompressOutcome(
      CompressOutcomeKind.unsupported,
    ),
    CompressMayHaveHappened() => const CompressOutcome(
      CompressOutcomeKind.couldntConfirm,
    ),
    CompressFailed() => const CompressOutcome(CompressOutcomeKind.failed),
  };

  Future<void> _rereadAfterCompress() async {
    await _refetchChat();
    await _refreshUsage();
    await _readBreakdownIfOpen();
  }

  Future<void> _refetchChat() async {
    try {
      await bridge.refetchChat();
    } on Object {
      // The chat stays as it was; the outcome line already says what is known.
    }
  }

  Future<void> _refreshUsage() async {
    try {
      await bridge.refreshUsage();
    } on Object {
      // Usage keeps its last value.
    }
  }

  void _notify() {
    if (_disposed) return;
    if (suggestionVisible && !_suggestionReported) {
      _suggestionReported = true;
      telemetry.crumb('chat.context.suggestion', {'action': 'shown'});
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _breakdownGeneration++;
    _epoch++;
    _breakdown = null;
    _usage = null;
    super.dispose();
  }
}
