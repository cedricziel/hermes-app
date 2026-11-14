import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import 'care_result.dart';
import 'log_line.dart';
import 'server_care_repository.dart';
import 'widgets/log_level_menu_button.dart';

/// The Logs page's state: the file, level and search the person chose, and
/// the lines Hermes answered for them, newest first.
///
/// Log lines can hold anything, so they live only here: never in
/// preferences, a breadcrumb, a span or a log. They are dropped when the
/// page closes ([dispose]), when App Lock covers the app ([cover]) and, as
/// the page is rebuilt for them, on sign-out, server change and profile
/// switch. A read always names its profile; an answer for something that has
/// since been replaced is dropped.
class ServerLogsController extends ChangeNotifier with SafeNotifier {
  ServerLogsController({
    required this.repository,
    String? profile,
    CareLogFile file = CareLogFile.errors,
    this.debounce = defaultDebounce,
    this.covered,
    this.onUnsupported,
    this.lookupFailed,
  }) : // A named parameter cannot be a private initializing formal.
       // ignore: prefer_initializing_formals
       _file = file,
       // ignore: prefer_initializing_formals
       _profile = profile;

  /// How long typing must pause before a search is sent.
  static const defaultDebounce = Duration(milliseconds: 400);

  /// Lines asked for first, and after "Show older".
  static const initialLines = 200;
  static const olderLines = 500;

  final ServerCareRepository repository;
  final Duration debounce;

  /// Whether App Lock covers the app; nothing is read then.
  final bool Function()? covered;

  /// Called when the server answered that it has no logs route.
  final VoidCallback? onUnsupported;

  /// Whether looking up the profile failed.
  final bool Function()? lookupFailed;

  CareLogFile _file;
  LogLevelFilter _level = LogLevelFilter.all;
  String _search = '';
  int _lines = initialLines;
  String? _profile;
  List<LogLine> _entries = const [];
  int _rawCount = 0;
  CareFailureKind? _failure;
  String? _failureMessage;
  bool _unsupported = false;
  bool _loading = false;
  bool _coveredHere = false;
  bool _answered = false;
  int _generation = 0;
  Timer? _typing;

  CareLogFile get file => _file;
  LogLevelFilter get level => _level;

  /// What is typed in the search field, as typed.
  String get search => _search;
  String? get profile => _profile;

  /// The lines of the last answer, newest first. Empty while covered.
  List<LogLine> get entries => _entries;

  /// True while a read runs.
  bool get loading => _loading;

  /// True once a read for the current choices was answered (even with
  /// nothing), so the page can tell "loading" from "empty".
  bool get answered => _answered;

  /// Why the last read failed; null when it succeeded.
  CareFailureKind? get failure => _failure;

  /// Hermes' own text for a refused read.
  String? get failureMessage => _failureMessage;

  /// True once the server answered that it has no logs route.
  bool get unsupported => _unsupported;

  /// Whether a level or a search narrows the lines.
  bool get filtered =>
      _level != LogLevelFilter.all || _search.trim().isNotEmpty;

  /// How many lines the current read asks for.
  int get requestedLines => _lines;

  /// Whether Show older would give more: the answer filled the 200 asked for.
  bool get canShowOlder =>
      _lines == initialLines && _answered && _rawCount >= initialLines;

  /// Whether the 500-line limit was reached, so there is nothing further.
  bool get reachedLimit => _lines == olderLines && _rawCount >= olderLines;

  /// Reads the logs for the current choices. Nothing is read while no
  /// profile is known or App Lock covers the app.
  Future<void> load() async {
    if (disposed) return;
    final profile = _profile;
    if (profile == null) {
      final failed = lookupFailed?.call() ?? false;
      _loading = !failed;
      _failure = failed ? CareFailureKind.offline : null;
      notifyListeners();
      return;
    }
    if (_coveredHere || (covered?.call() ?? false)) {
      _loading = false;
      return;
    }
    final generation = ++_generation;
    _loading = true;
    notifyListeners();
    final result = await repository.logs(
      profile: profile,
      file: _file,
      lines: _lines,
      level: switch (_level) {
        LogLevelFilter.all => null,
        LogLevelFilter.warnings => 'WARNING',
        LogLevelFilter.errors => 'ERROR',
      },
      search: _search.trim().isEmpty ? null : _search.trim(),
    );
    if (generation != _generation || disposed) return;
    _loading = false;
    _answered = true;
    switch (result) {
      case CareOk(:final value):
        _entries = value.reversed.toList(growable: false);
        _rawCount = value.fold<int>(0, (n, e) => n + 1 + e.continuation.length);
        _failure = null;
        _failureMessage = null;
        _unsupported = false;
      case CareUnsupported():
        _drop();
        _unsupported = true;
        onUnsupported?.call();
      case CareFailed(:final kind, :final message):
        // Lines of an earlier answer would be for other choices.
        _drop();
        _failure = kind;
        _failureMessage = message;
    }
    notifyListeners();
  }

  void setFile(CareLogFile file) {
    if (file == _file) return;
    _file = file;
    _replaced();
  }

  void setLevel(LogLevelFilter level) {
    if (level == _level) return;
    _level = level;
    _replaced();
  }

  /// Sends the search once typing paused for [debounce].
  void setSearch(String search) {
    if (search == _search) return;
    _search = search;
    _typing?.cancel();
    // Whatever was asked before is for another search now.
    _generation++;
    _typing = Timer(debounce, _replaced);
    notifyListeners();
  }

  void clearFilters() {
    _typing?.cancel();
    _level = LogLevelFilter.all;
    _search = '';
    _replaced();
  }

  void setProfile(String? profile) {
    if (profile == _profile) return;
    _profile = profile;
    _replaced();
  }

  /// Asks for 500 lines instead of 200, with the same choices.
  Future<void> showOlder() {
    _lines = olderLines;
    return load();
  }

  /// App Lock covers the app: the lines go, and nothing is read until
  /// [uncover].
  void cover() {
    _coveredHere = true;
    _typing?.cancel();
    _generation++;
    _loading = false;
    _drop();
    notifyListeners();
  }

  /// App Lock let go: the lines are read again.
  void uncover() {
    if (!_coveredHere) return;
    _coveredHere = false;
    _replaced();
  }

  void _drop() {
    _entries = const [];
    _rawCount = 0;
    _failure = null;
    _failureMessage = null;
    _unsupported = false;
    _answered = false;
  }

  void _replaced() {
    _typing?.cancel();
    _typing = null;
    _lines = initialLines;
    _drop();
    // An answer still on its way belongs to what was replaced.
    _generation++;
    _loading = false;
    notifyListeners();
    unawaited(load());
  }

  @override
  void dispose() {
    _typing?.cancel();
    _drop();
    super.dispose();
  }
}
