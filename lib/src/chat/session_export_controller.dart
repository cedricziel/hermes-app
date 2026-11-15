import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../api/hermes_api_client.dart';
import 'session_export.dart';
import 'session_export_telemetry.dart';
import 'widgets/session_export_alert.dart';
import 'widgets/session_export_failure.dart';

/// Hands the received bytes to the system's save sheet. True when the user
/// saved, false when they cancelled.
typedef SessionExportSave = Future<bool> Function(
  String fileName,
  Uint8List bytes,
);

/// How a confirmed export ended once it reached the save sheet.
enum SessionExportSaveResult {
  /// The file was written; the caller shows "Chat saved".
  saved,

  /// The user cancelled the save sheet; the caller shows nothing.
  cancelled,

  /// App Lock locked while the sheet was open; the caller shows nothing.
  droppedByLock,
}

/// How long the request may stay without a first byte before the alert says it
/// is still waiting.
const sessionExportStallAfter = Duration(seconds: 10);

/// Runs "Export chat as JSON": confirm, fetch, save, one at a time. It never
/// resends a request: a failure, a retry or a lock ends in the confirmation or
/// in nothing, and only [confirm] sends.
///
/// The received bytes live in memory only until the save sheet returns or the
/// export is dropped (cancel, a profile or server change, sign-out, App Lock),
/// and nothing of the chat (id, profile, file name, body) reaches a log, a
/// crash report or an error message.
class SessionExportController extends ChangeNotifier {
  SessionExportController({
    required this._api,
    required this._save,
    this.telemetry = const SessionExportTelemetry(),
    this.clearTemporaryFiles,
    this._timer = Timer.new,
  });

  final HermesApiClient _api;
  final SessionExportSave _save;
  final SessionExportTelemetry telemetry;

  /// Removes what the save sheet staged (the picker's temporary files on iOS);
  /// null where there is nothing to remove.
  final Future<void> Function()? clearTemporaryFiles;
  final Timer Function(Duration, void Function()) _timer;

  SessionExportPhase? _phase;
  String? _sessionId;
  String? _profile;
  String? _fileName;
  Span? _span;
  int _received = 0;
  bool _running = false;
  bool _saving = false;
  bool _lockedDuringSave = false;
  bool _disposed = false;
  int _run = 0;
  CancelToken? _token;
  Timer? _stall;
  Uint8List? _bytes;

  /// What the alert shows; null while no export is open.
  SessionExportPhase? get phase => _phase;

  /// Whether a fetch or a save is in flight; the menus disable the row.
  bool get busy => _running;

  /// Whether received bytes are still held, for tests.
  @visibleForTesting
  bool get holdsBytes => _bytes != null;

  /// Opens the confirmation for [sessionId]. False, with nothing shown or
  /// sent, when the chat has no [profile] or an export is already running.
  /// [fileName] is what the save sheet proposes; it stays on the device.
  bool begin(String sessionId, String? profile, {String? fileName}) {
    if (_running || profile == null || sessionId.isEmpty) return false;
    _sessionId = sessionId;
    _profile = profile;
    _fileName = fileName ?? 'session-$sessionId.json';
    _set(const SessionExportConfirm());
    return true;
  }

  /// Sends the request for the chat [begin] named. A second press while one
  /// runs sends nothing. Completes with how the save sheet ended, or null when
  /// there was no save (a failure, a cancel, a drop).
  Future<SessionExportSaveResult?> confirm() async {
    final id = _sessionId;
    final profile = _profile;
    if (_running || _phase is! SessionExportConfirm) return null;
    if (id == null || profile == null) return null;
    _running = true;
    final run = ++_run;
    final token = _token = CancelToken();
    _received = 0;
    telemetry.started();
    final span = _span = telemetry.startFetch();
    _set(const SessionExportProgress());
    _stall = _timer(sessionExportStallAfter, () {
      if (run == _run && _received == 0) {
        _set(const SessionExportProgress(stalled: true));
      }
    });

    SessionExportFailure? failure;
    int? messages;
    try {
      final bytes = await _api.fetchSessionExport(
        id,
        profile: profile,
        cancelToken: token,
        onProgress: (n) {
          if (run != _run || n <= 0) return;
          _received = n;
          _stall?.cancel();
          _set(SessionExportProgress(receivedBytes: n));
        },
      );
      if (run != _run) return null;
      _bytes = bytes;
      _received = bytes.length;
      messages = (await decodeSessionExport(bytes)).messageCount;
    } on SessionExportCancelled {
      // Cancel, sign-out or an owner change ended it. A drop already closed
      // the alert; a connection that ended under the request did not.
      if (run == _run) _drop();
      return null;
    } on SessionExportRequestFailed catch (e) {
      failure = e.kind;
    } on SessionExportIncomplete {
      failure = SessionExportFailure.incomplete;
    } on Object {
      failure = SessionExportFailure.failed;
    }
    if (run != _run) return null; // dropped while decoding
    _stall?.cancel();
    if (failure != null) {
      _bytes = null;
      _running = false;
      _span = null;
      telemetry.endFetch(span, failure: failure, bytes: _received);
      _set(SessionExportFailed(failure));
      return null;
    }
    _span = null;
    telemetry.endFetch(span, bytes: _received, messages: messages);
    return _saveBytes(run, id);
  }

  Future<SessionExportSaveResult?> _saveBytes(int run, String id) async {
    final bytes = _bytes!;
    _saving = true;
    _lockedDuringSave = false;
    // The alert closes behind the save sheet.
    _set(null);
    SessionExportSaveResult? result;
    try {
      final saved = await _save(_fileName ?? 'session-$id.json', bytes);
      result = saved
          ? SessionExportSaveResult.saved
          : SessionExportSaveResult.cancelled;
    } on Object {
      result = null;
    }
    final locked = _lockedDuringSave;
    _bytes = null;
    _saving = false;
    _lockedDuringSave = false;
    await _clearTemporary();
    if (run != _run && !locked) {
      // Dropped by a sign-out or a change while the sheet was open.
      _running = false;
      return null;
    }
    _running = false;
    if (result == null) {
      telemetry.saveFailed();
      _set(const SessionExportFailed(SessionExportFailure.failed));
      return null;
    }
    if (locked) return SessionExportSaveResult.droppedByLock;
    result == SessionExportSaveResult.saved
        ? telemetry.saved()
        : telemetry.cancelled();
    notifyListeners();
    return result;
  }

  /// The user pressed Cancel: ends the request and closes the alert silently.
  void cancel() {
    if (_phase == null) return;
    if (_running && !_saving) telemetry.cancelled();
    _drop();
  }

  /// Try again: back to the confirmation, never a request.
  void retry() {
    if (_phase is SessionExportFailed && !_running) {
      _set(const SessionExportConfirm());
    }
  }

  /// Closes a failure or the confirmation.
  void close() {
    if (_running) return;
    _set(null);
  }

  /// The chat's profile or the server changed.
  void contextChanged() => _drop();

  /// The user signed out.
  void signedOut() {
    _drop();
    unawaited(_clearTemporary());
  }

  /// App Lock locked: drops everything, and a save sheet that is open will
  /// report [SessionExportSaveResult.droppedByLock].
  void locked() {
    if (_saving) _lockedDuringSave = true;
    _drop();
    unawaited(_clearTemporary());
  }

  void _drop() {
    _run++;
    _stall?.cancel();
    _token?.cancel();
    _token = null;
    _bytes = null;
    final span = _span;
    _span = null;
    if (span != null) {
      telemetry.endFetch(span, cancelled: true, bytes: _received);
    }
    if (!_saving) _running = false;
    _set(null);
  }

  Future<void> _clearTemporary() async {
    try {
      await clearTemporaryFiles?.call();
    } on Object {
      return;
    }
  }

  void _set(SessionExportPhase? phase) {
    _phase = phase;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _drop();
    super.dispose();
  }
}
