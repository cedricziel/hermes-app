import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import 'care_result.dart';
import 'server_care_repository.dart';
import 'update_check.dart';

/// The state of `GET /api/hermes/update/check`, shared by the Server screen's
/// Updates row and the Update page. Owned by the screen that opens the page.
class UpdateCheckController extends ChangeNotifier with SafeNotifier {
  UpdateCheckController({
    required this.repository,
    this.onUnsupported,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ServerCareRepository repository;

  /// Called once when the server has no update route.
  final VoidCallback? onUnsupported;
  final DateTime Function() _now;

  UpdateCheck? _check;
  CareFailed<UpdateCheck>? _failure;
  bool _loading = false;
  bool _supported = true;
  bool _everChecked = false;
  DateTime? _checkedAt;
  int _generation = 0;

  bool get loading => _loading;

  /// False once the server answered that it has no update route.
  bool get supported => _supported;

  /// Whether a check has been started, so a page that opens later asks only
  /// when nobody did.
  bool get everChecked => _everChecked;
  UpdateCheck? get current => _check;
  DateTime? get checkedAt => _checkedAt;

  /// Asks the server; [force] skips Hermes' own cache of the answer.
  Future<void> check({bool force = false}) async {
    if (disposed) return;
    final generation = ++_generation;
    _everChecked = true;
    _loading = true;
    notifyListeners();
    final result = await repository.checkUpdate(force: force);
    if (generation != _generation || disposed) return;
    switch (result) {
      case CareOk(:final value):
        _check = value;
        _failure = null;
        _supported = true;
        _checkedAt = _now();
      case CareUnsupported():
        final first = _supported;
        _check = null;
        _failure = null;
        _supported = false;
        if (first) onUnsupported?.call();
      case CareFailed():
        _failure = result;
    }
    _loading = false;
    notifyListeners();
  }

  /// What the check says, or null when the server has no update route or the
  /// first check is not back and nothing is known. The widget layer words it.
  UpdateState? state({String? fallbackVersion}) {
    if (!_supported) return null;
    if (_loading && _check == null) return const UpdateStateChecking();
    final failure = _failure;
    // A failed check is said even when an earlier one succeeded: the old
    // answer is not what the server says now.
    if (failure != null && !_loading) {
      return UpdateStateFailed(
        message: failure.message,
        reason: failure.kind == CareFailureKind.offline
            ? UpdateFailureReason.offline
            : UpdateFailureReason.checkFailed,
      );
    }
    final check = _check;
    if (check == null) return null;
    if (_loading) return const UpdateStateChecking();
    return _stateOf(check, fallbackVersion);
  }

  UpdateState _stateOf(UpdateCheck check, String? fallbackVersion) {
    final version = check.currentVersion ?? fallbackVersion ?? '';
    final behind = check.behind;
    if (check.updateAvailable) {
      final stable = check.rollbackTo;
      final count = (behind == null || behind < 0)
          ? check.commits.length
          : behind;
      if (stable != null) {
        return UpdateStateRollback(
          stableVersion: stable,
          changeCount: count,
          currentVersion: version.isEmpty ? null : version,
        );
      }
      if (!check.canApply) {
        return UpdateStateCannotApply(
          message: check.message,
          command: check.updateCommand,
        );
      }
      return UpdateStateAvailable(changeCount: count, currentVersion: version);
    }
    if (behind == null) {
      // Managed installs have nothing to check; they say so in their message.
      if (check.installMethod == InstallMethod.managedRuntime &&
          check.message != null) {
        return UpdateStateCannotApply(message: check.message);
      }
      return UpdateStateFailed(
        message: check.message,
        reason: UpdateFailureReason.noResult,
      );
    }
    return UpdateStateUpToDate(version: version, checkedAgo: _ago());
  }

  Elapsed _ago() {
    final at = _checkedAt;
    if (at == null) return const Elapsed(ElapsedUnit.justNow);
    final minutes = _now().difference(at).inMinutes;
    if (minutes < 1) return const Elapsed(ElapsedUnit.justNow);
    if (minutes < 60) return Elapsed(ElapsedUnit.minutes, minutes);
    return Elapsed(ElapsedUnit.hours, minutes ~/ 60);
  }

  /// The Updates row's state; [UpdateRowKind.none] when there is nothing to
  /// say (a managed install).
  ({UpdateRowKind kind, int? changeCount}) rowState({
    String? fallbackVersion,
  }) => switch (state(fallbackVersion: fallbackVersion)) {
    null => (kind: UpdateRowKind.none, changeCount: null),
    UpdateStateChecking() => (kind: UpdateRowKind.checking, changeCount: null),
    UpdateStateUpToDate() => (kind: UpdateRowKind.upToDate, changeCount: null),
    UpdateStateFailed() => (kind: UpdateRowKind.failed, changeCount: null),
    UpdateStateAvailable(:final changeCount) ||
    UpdateStateRollback(
      :final changeCount?,
    ) => (kind: UpdateRowKind.available, changeCount: changeCount),
    UpdateStateRollback() => (kind: UpdateRowKind.available, changeCount: null),
    UpdateStateCannotApply() => (
      kind: _check?.updateAvailable ?? false
          ? UpdateRowKind.available
          : UpdateRowKind.none,
      changeCount: null,
    ),
  };

  /// The version a check last reported, for the status card.
  String? get version => _check?.currentVersion;

  List<UpdateCommitEntry> get changes => [
    for (final c in _check?.commits.take(20) ?? const <UpdateCommit>[])
      UpdateCommitEntry(
        summary: c.summary,
        author: c.author,
        when: c.at == null ? null : _since(c.at!),
      ),
  ];

  Elapsed _since(int unixSeconds) {
    final days = _now()
        .difference(DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000))
        .inDays;
    return days < 1
        ? const Elapsed(ElapsedUnit.today)
        : Elapsed(ElapsedUnit.days, days);
  }
}

/// A span of time as a unit and a count, worded by the widget layer.
enum ElapsedUnit { justNow, minutes, hours, today, days }

class Elapsed {
  const Elapsed(this.unit, [this.count = 0]);

  final ElapsedUnit unit;
  final int count;
}

/// Why a check has nothing to report, when Hermes gave no text of its own.
enum UpdateFailureReason { offline, checkFailed, noResult }

enum UpdateRowKind { none, checking, upToDate, failed, available }

/// One commit of the update's change list: Hermes' own summary and author.
class UpdateCommitEntry {
  const UpdateCommitEntry({required this.summary, this.author, this.when});

  final String summary;
  final String? author;
  final Elapsed? when;
}

/// What an update check says, without wording. [message] is Hermes' own
/// text where a case has one.
sealed class UpdateState {
  const UpdateState();
}

class UpdateStateChecking extends UpdateState {
  const UpdateStateChecking();
}

class UpdateStateUpToDate extends UpdateState {
  const UpdateStateUpToDate({required this.version, required this.checkedAgo});

  final String version;
  final Elapsed checkedAgo;
}

class UpdateStateFailed extends UpdateState {
  const UpdateStateFailed({this.message, required this.reason});

  final String? message;
  final UpdateFailureReason reason;
}

class UpdateStateAvailable extends UpdateState {
  const UpdateStateAvailable({
    required this.changeCount,
    required this.currentVersion,
  });

  final int changeCount;
  final String currentVersion;
}

class UpdateStateRollback extends UpdateState {
  const UpdateStateRollback({
    required this.stableVersion,
    this.changeCount,
    this.currentVersion,
  });

  final String stableVersion;
  final int? changeCount;
  final String? currentVersion;
}

class UpdateStateCannotApply extends UpdateState {
  const UpdateStateCannotApply({this.message, this.command});

  final String? message;
  final String? command;
}
