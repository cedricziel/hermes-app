import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../../core/safe_notifier.dart';
import '../../telemetry/report_bug.dart';
import 'soul_repository.dart';
import 'soul_telemetry.dart';

/// How long the read before a save, the PUT and a Check may go unanswered
/// (and a plain read). A request that gets none ends in a failure the user can
/// act on; nothing is ever resent.
const kSoulAnswerTimeout = Duration(seconds: 10);

/// Where loading the file stands. The editor exists only for [loaded] and
/// [notSet]: a failed read never shows an empty one the user could save over
/// the file the app could not read.
enum SoulLoad {
  loading,

  /// The file was read (it may be empty).
  loaded,

  /// There is no SOUL.md on the server yet.
  notSet,

  /// The read was refused, answered with a 5xx or could not be parsed.
  failed,

  /// 404 naming the profile: it is gone.
  profileGone,

  /// The server has no such route: the entry points go away.
  unsupported,

  /// The read got no answer.
  offline,
}

/// What the page says about the last save.
enum SoulStatus {
  /// Nothing to say beyond [SoulController.dirty].
  idle,

  /// The save question is open; nothing has been sent.
  asking,

  /// The second read before a PUT runs. The editor is read-only.
  verifying,

  /// The PUT runs. The editor is read-only.
  saving,

  /// The text is on the server.
  saved,

  /// The server refused the write; nothing changed there.
  saveFailed,

  /// The PUT got no answer (or a 200 without `ok`): it may have gone through.
  /// Check reads the file to find out.
  lostAnswer,

  /// A Check read runs. The editor is read-only.
  checking,

  /// The read before a save failed or timed out. Nothing was sent.
  saveCheckFailed,

  /// The Check read failed or timed out. The lost answer still stands.
  lostCheckFailed,

  /// The file differs from what the page last knew. Nothing was sent; see
  /// [SoulController.serverText].
  changedOnServer,

  /// Check found the earlier text: the server did not take the save (yet).
  earlierText,
}

/// What the save question needs to word itself.
class SoulSaveQuestion {
  const SoulSaveQuestion({
    required this.profile,
    required this.empty,
    required this.pendingSaveNote,
  });

  /// Shown in the title, never logged.
  final String profile;

  /// The text to send is empty: Hermes falls back to its default personality.
  final bool empty;

  /// A Check found the earlier text: an earlier save may still be pending.
  final bool pendingSaveNote;
}

typedef _Baseline = ({bool exists, String content});

/// One visit to the Personality page of a profile: the file's text, its
/// baseline, and the guarded save.
///
/// It is bound to one profile name (explicit in the path, never the server's
/// active profile) and one connection. Sign-out, a server change and a
/// profile switch end it with [clear] or [dispose]; App Lock calls [cover]
/// (everything goes at once, nothing is kept) and [uncover] (the server's
/// text is read again). An answer that arrives for anything dropped is
/// ignored, and nothing notifies after [dispose].
///
/// Save sends nothing until the question from [requestSave] is confirmed with
/// [confirmSave]; that reads the file first and sends only when it still is
/// what the page last knew. A PUT is sent once and never resent.
class SoulController extends ChangeNotifier with SafeNotifier {
  SoulController({
    required this._repository,
    required this.profile,
    SoulTelemetry? telemetry,
    this._openedFrom = SoulOpenedFrom.sidebar,
    this._answerTimeout = kSoulAnswerTimeout,
    this._onUnsupported,
  }) : _telemetry = telemetry ?? SoulTelemetry();

  final SoulRepository _repository;
  final SoulTelemetry _telemetry;
  final SoulOpenedFrom _openedFrom;
  final Duration _answerTimeout;
  final VoidCallback? _onUnsupported;

  /// The profile this page is bound to.
  final String profile;

  static const _nothing = (exists: false, content: '');

  var _load = SoulLoad.loading;
  var _status = SoulStatus.idle;
  var _statusBeforeQuestion = SoulStatus.idle;
  SoulFailureKind? _loadFailure;
  SoulFailureKind? _saveFailure;

  _Baseline _baseline = _nothing;
  var _text = '';

  /// The text the question was confirmed for, and the one Replace anyway sends.
  String? _pendingText;

  /// The text of a PUT whose outcome is not known.
  String? _sentText;
  var _pendingNote = false;
  String? _serverText;
  bool? _serverExists;

  /// Moves on whenever something replaces what an answer in flight belonged to.
  var _generation = 0;
  var _opened = false;
  var _covered = false;
  var _closed = false;
  var _toldUnsupported = false;

  SoulLoad get load => _load;
  SoulStatus get status => _status;

  /// Why the read failed, when [load] says it did.
  SoulFailureKind? get loadFailure => _loadFailure;

  /// Why the server refused the last write, when [status] is
  /// [SoulStatus.saveFailed].
  SoulFailureKind? get saveFailure => _saveFailure;

  /// The editor's text. Empty whenever there is no editor.
  String get text => _text;

  /// Whether the server held a file at the last read or save.
  bool get exists => _baseline.exists;

  /// Whether the text differs from the last read or saved text.
  bool get dirty => showsEditor && _text != _baseline.content;

  bool get showsEditor =>
      !_closed &&
      !_covered &&
      (_load == SoulLoad.loaded || _load == SoulLoad.notSet);

  /// A read or a write is running.
  bool get busy =>
      _status == SoulStatus.verifying ||
      _status == SoulStatus.saving ||
      _status == SoulStatus.checking;

  /// The editor is read-only so the baseline cannot race the text.
  bool get readOnly => busy;

  bool get canSave =>
      showsEditor &&
      dirty &&
      !busy &&
      _status != SoulStatus.asking &&
      _status != SoulStatus.changedOnServer;

  /// A save's outcome is unknown, so a read can settle it.
  bool get canCheck =>
      showsEditor &&
      !busy &&
      _sentText != null &&
      _status != SoulStatus.asking &&
      _status != SoulStatus.changedOnServer;

  /// A Check found the earlier text: the next question says a save may still
  /// be pending.
  bool get pendingSaveNote => _pendingNote;

  /// The file's text on the server while [status] is
  /// [SoulStatus.changedOnServer]; null otherwise.
  String? get serverText => _serverText;

  /// Whether the file exists on the server (while changed on the server).
  bool? get serverExists => _serverExists;

  /// App Lock covers the page: nothing is held or read.
  bool get covered => _covered;

  /// [clear] or [dispose] ended the controller.
  bool get closed => _closed;

  /// Records that the page opened and reads the file.
  Future<void> start() async {
    if (_closed || _covered) return;
    if (!_opened) {
      _opened = true;
      _telemetry.opened(_openedFrom);
    }
    await _read();
  }

  /// Reads the file again (Try again). Drops the editor's text.
  Future<void> reload() async {
    if (_closed || _covered || busy) return;
    await _read();
  }

  void setText(String value) {
    if (!showsEditor || readOnly || value == _text) return;
    _text = value;
    if (_status == SoulStatus.saved ||
        _status == SoulStatus.saveFailed ||
        _status == SoulStatus.saveCheckFailed ||
        _status == SoulStatus.asking) {
      _status = _resting();
      _pendingText = null;
    }
    notifyListeners();
  }

  /// Puts the baseline text back. The page asks "Discard changes?" first
  /// (when [dirty]).
  void revert() {
    if (!showsEditor || readOnly) return;
    _text = _baseline.content;
    if (_status == SoulStatus.saved ||
        _status == SoulStatus.saveFailed ||
        _status == SoulStatus.saveCheckFailed ||
        _status == SoulStatus.asking ||
        _status == SoulStatus.changedOnServer) {
      _status = _resting();
      _pendingText = null;
      _dropServerText();
    }
    notifyListeners();
  }

  /// The save question for the text as it is now, or null when there is
  /// nothing to save or something is running. Sends nothing.
  SoulSaveQuestion? requestSave() {
    if (!canSave) return null;
    _statusBeforeQuestion = _status;
    _pendingText = _text;
    _status = SoulStatus.asking;
    notifyListeners();
    return SoulSaveQuestion(
      profile: profile,
      empty: _text.isEmpty,
      pendingSaveNote: _pendingNote,
    );
  }

  /// The user said Cancel to the question.
  void cancelSave() {
    if (_status != SoulStatus.asking) return;
    _status = _statusBeforeQuestion;
    _pendingText = null;
    notifyListeners();
  }

  /// The user confirmed the question (or pressed Try again after a failed
  /// check read): reads the file, then sends once if nothing changed there.
  Future<void> confirmSave() async {
    final text = _pendingText;
    if (_closed ||
        _covered ||
        text == null ||
        (_status != SoulStatus.asking &&
            _status != SoulStatus.saveCheckFailed)) {
      return;
    }
    final generation = _generation;
    _telemetry.saveConfirmed();
    final span = _telemetry.startSave();
    _status = SoulStatus.verifying;
    notifyListeners();

    final (:soul, :failure) = await _tryRead();
    if (generation != _generation) return _discardSave(span, text);
    if (soul == null) {
      if (_leaveFor(failure!)) {
        _telemetry.endSave(
          span,
          SoulSaveOutcome.checkFailed,
          empty: text.isEmpty,
          length: text.length,
        );
        return;
      }
      _status = SoulStatus.saveCheckFailed;
      _telemetry.endSave(
        span,
        SoulSaveOutcome.checkFailed,
        empty: text.isEmpty,
        length: text.length,
      );
      notifyListeners();
      return;
    }
    // An unconfirmed earlier save landed. A missing file never counts, so an
    // empty text still creates it.
    if (soul.exists && soul.content == text) {
      _settle(text);
      _telemetry.endSave(
        span,
        SoulSaveOutcome.saved,
        empty: text.isEmpty,
        length: text.length,
      );
      _telemetry.saved(SoulSaveOutcome.saved, empty: text.isEmpty);
      notifyListeners();
      return;
    }
    if (_differsFromBaseline(soul)) {
      _conflict(soul, text);
      _telemetry.endSave(
        span,
        SoulSaveOutcome.conflict,
        empty: text.isEmpty,
        length: text.length,
      );
      notifyListeners();
      return;
    }
    await _put(text, span, SoulSaveOutcome.saved);
  }

  /// "Keep editing" on the changed-on-server question: nothing is sent.
  void keepEditing() {
    if (_status != SoulStatus.changedOnServer) return;
    final empty = (_pendingText ?? _text).isEmpty;
    _dropServerText();
    _pendingText = null;
    _status = _resting();
    _telemetry.saved(SoulSaveOutcome.conflictKept, empty: empty);
    notifyListeners();
  }

  /// "Replace anyway": sends the text once, without reading again.
  Future<void> replaceAnyway() async {
    final text = _pendingText;
    if (_closed ||
        _covered ||
        text == null ||
        _status != SoulStatus.changedOnServer) {
      return;
    }
    final span = _telemetry.startSave();
    _dropServerText();
    await _put(text, span, SoulSaveOutcome.conflictReplaced);
  }

  /// Reads the file after a lost answer and compares it with the text that
  /// was sent (not the editor, which may have changed since).
  Future<void> check() async {
    final sent = _sentText;
    if (!canCheck || sent == null) return;
    final generation = _generation;
    final span = _telemetry.startFetch();
    _status = SoulStatus.checking;
    notifyListeners();

    final (:soul, :failure) = await _tryRead();
    if (generation != _generation) {
      _telemetry.endFetch(span, 'discarded');
      return;
    }
    if (soul == null) {
      _telemetry.endFetch(span, _fetchOutcome(failure!));
      if (_leaveFor(failure)) return;
      _status = SoulStatus.lostCheckFailed;
      notifyListeners();
      return;
    }
    _telemetry.endFetch(span, 'ok', exists: soul.exists);
    if (soul.exists && soul.content == sent) {
      _settle(sent);
      _telemetry.saved(SoulSaveOutcome.saved, empty: sent.isEmpty);
    } else if (!_differsFromBaseline(soul)) {
      _status = SoulStatus.earlierText;
      _pendingNote = true;
    } else {
      _conflict(soul, _text);
    }
    notifyListeners();
  }

  /// App Lock covers the app: the text, the server's text and every pending
  /// state go at once. A request in flight finishes and its outcome is
  /// dropped; [uncover] reads the file again.
  void cover() {
    if (_closed) return;
    _covered = true;
    _generation++;
    _dropAll();
    _load = SoulLoad.loading;
    notifyListeners();
  }

  /// App Lock let go: the server's text is read again.
  void uncover() {
    if (_closed || !_covered) return;
    _covered = false;
    unawaited(_read());
  }

  /// Sign-out, server change or profile switch: drops everything and ends the
  /// controller.
  void clear() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _dropAll();
    _load = SoulLoad.loading;
    notifyListeners();
  }

  @override
  void dispose() {
    if (disposed) return;
    _closed = true;
    _generation++;
    _dropAll();
    super.dispose();
  }

  Future<void> _read() async {
    final generation = ++_generation;
    _dropAll();
    _load = SoulLoad.loading;
    notifyListeners();
    final span = _telemetry.startFetch();
    final (:soul, :failure) = await _tryRead();
    if (generation != _generation) {
      _telemetry.endFetch(span, 'discarded');
      return;
    }
    if (soul == null) {
      _telemetry.endFetch(span, _fetchOutcome(failure!));
      _failLoad(failure);
    } else {
      _telemetry.endFetch(span, 'ok', exists: soul.exists);
      _baseline = (exists: soul.exists, content: soul.content);
      _text = soul.content;
      _load = soul.exists ? SoulLoad.loaded : SoulLoad.notSet;
    }
    notifyListeners();
  }

  /// Sends [text] once. [span] is the save span already started.
  Future<void> _put(String text, Span? span, SoulSaveOutcome saved) async {
    final generation = _generation;
    final previous = _sentText;
    _sentText = text;
    _status = SoulStatus.saving;
    notifyListeners();

    final (:result, :failure) = await _tryWrite(text);
    if (generation != _generation) return _discardSave(span, text);
    final empty = text.isEmpty;
    final length = text.length;
    if (failure == null && result == SoulWriteResult.saved) {
      _settle(text);
      _telemetry.endSave(span, saved, empty: empty, length: length);
      _telemetry.saved(saved, empty: empty);
    } else if (failure == null || failure == SoulFailureKind.lostAnswer) {
      _status = SoulStatus.lostAnswer;
      _telemetry.endSave(
        span,
        SoulSaveOutcome.unconfirmed,
        empty: empty,
        length: length,
      );
      _telemetry.saved(SoulSaveOutcome.unconfirmed, empty: empty);
    } else {
      _sentText = previous;
      _telemetry.endSave(
        span,
        SoulSaveOutcome.failed,
        empty: empty,
        length: length,
      );
      _telemetry.saved(SoulSaveOutcome.failed, empty: empty);
      if (!_leaveFor(failure, notify: false)) {
        _saveFailure = failure;
        _status = SoulStatus.saveFailed;
      }
    }
    notifyListeners();
  }

  void _discardSave(Span? span, String text) => _telemetry.endSave(
    span,
    SoulSaveOutcome.discarded,
    empty: text.isEmpty,
    length: text.length,
  );

  /// The server holds [text]: it is the baseline, no outcome is pending.
  /// Edits made since stay edits.
  void _settle(String text) {
    _baseline = (exists: true, content: text);
    _sentText = null;
    _pendingText = null;
    _pendingNote = false;
    _saveFailure = null;
    _status = SoulStatus.saved;
  }

  void _conflict(ProfileSoul soul, String pending) {
    _serverText = soul.content;
    _serverExists = soul.exists;
    _pendingText = pending;
    _status = SoulStatus.changedOnServer;
  }

  bool _differsFromBaseline(ProfileSoul soul) =>
      soul.exists != _baseline.exists || soul.content != _baseline.content;

  /// What the page shows when no question, sheet or run is on.
  SoulStatus _resting() =>
      _sentText == null ? SoulStatus.idle : SoulStatus.lostAnswer;

  void _dropServerText() {
    _serverText = null;
    _serverExists = null;
  }

  void _dropAll() {
    _baseline = _nothing;
    _text = '';
    _pendingText = null;
    _sentText = null;
    _pendingNote = false;
    _dropServerText();
    _loadFailure = null;
    _saveFailure = null;
    _status = SoulStatus.idle;
    _statusBeforeQuestion = SoulStatus.idle;
  }

  /// A failure that ends the page's editor (profile gone, route missing).
  /// Returns whether it did.
  bool _leaveFor(SoulFailureKind kind, {bool notify = true}) {
    if (kind != SoulFailureKind.profileGone &&
        kind != SoulFailureKind.unsupported) {
      return false;
    }
    _failLoad(kind);
    if (notify) notifyListeners();
    return true;
  }

  void _failLoad(SoulFailureKind kind) {
    _dropAll();
    _loadFailure = kind;
    _load = switch (kind) {
      SoulFailureKind.profileGone => SoulLoad.profileGone,
      SoulFailureKind.unsupported => SoulLoad.unsupported,
      SoulFailureKind.unreachable => SoulLoad.offline,
      _ => SoulLoad.failed,
    };
    if (kind == SoulFailureKind.unsupported && !_toldUnsupported) {
      _toldUnsupported = true;
      _onUnsupported?.call();
    }
  }

  static String _fetchOutcome(SoulFailureKind kind) => switch (kind) {
    SoulFailureKind.profileGone => 'profile_gone',
    SoulFailureKind.unsupported => 'unsupported',
    SoulFailureKind.unreachable => 'offline',
    _ => 'failed',
  };

  Future<({ProfileSoul? soul, SoulFailureKind? failure})> _tryRead() async {
    try {
      final soul = await _repository.read(profile).timeout(_answerTimeout);
      return (soul: soul, failure: null);
    } on SoulFailure catch (failure) {
      return (soul: null, failure: failure.kind);
    } on TimeoutException {
      return (soul: null, failure: SoulFailureKind.unreachable);
    } on DioException {
      // A 401 the sign-in path handles; the read did not happen.
      return (soul: null, failure: SoulFailureKind.unexpected);
    } on Object catch (error, stack) {
      reportBug(error, stack, 'profile_soul.read');
      return (soul: null, failure: SoulFailureKind.unexpected);
    }
  }

  Future<({SoulWriteResult? result, SoulFailureKind? failure})> _tryWrite(
    String text,
  ) async {
    try {
      final result = await _repository
          .write(profile, text)
          .timeout(_answerTimeout);
      return (result: result, failure: null);
    } on SoulFailure catch (failure) {
      return (result: null, failure: failure.kind);
    } on TimeoutException {
      return (result: null, failure: SoulFailureKind.lostAnswer);
    } on DioException {
      // A 401: the server refused before it wrote anything.
      return (result: null, failure: SoulFailureKind.unexpected);
    } on Object catch (error, stack) {
      reportBug(error, stack, 'profile_soul.write');
      return (result: null, failure: SoulFailureKind.lostAnswer);
    }
  }
}
