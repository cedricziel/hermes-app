import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import 'care_result.dart';
import 'server_care_repository.dart';
import 'update_check.dart';
import 'widgets/update_status_card.dart';

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

  /// The card's state, or null when the server has no update route or the
  /// first check is not back and nothing is known.
  UpdateStatus? status({String? fallbackVersion}) {
    if (!_supported) return null;
    if (_loading && _check == null) return const UpdateChecking();
    final failure = _failure;
    // A failed check is said even when an earlier one succeeded: the old
    // answer is not what the server says now.
    if (failure != null && !_loading) {
      return UpdateCheckFailed(message: _failureText(failure));
    }
    final check = _check;
    if (check == null) return null;
    if (_loading) return const UpdateChecking();
    return _statusOf(check, fallbackVersion);
  }

  UpdateStatus _statusOf(UpdateCheck check, String? fallbackVersion) {
    final version = check.currentVersion ?? fallbackVersion ?? '';
    final behind = check.behind;
    if (check.updateAvailable) {
      final stable = check.rollbackTo;
      final count = (behind == null || behind < 0)
          ? check.commits.length
          : behind;
      if (stable != null) {
        return UpdateRollback(
          stableVersion: stable,
          changeCount: count,
          currentVersion: version.isEmpty ? null : version,
        );
      }
      if (!check.canApply) {
        return UpdateCannotApply(
          message: check.message ?? 'Update Hermes on the server.',
          command: check.updateCommand,
        );
      }
      return UpdateAvailable(changeCount: count, currentVersion: version);
    }
    if (behind == null) {
      // Managed installs have nothing to check; they say so in their message.
      if (check.installMethod == InstallMethod.managedRuntime &&
          check.message != null) {
        return UpdateCannotApply(message: check.message!);
      }
      return UpdateCheckFailed(
        message: check.message ?? "Couldn't check for updates.",
      );
    }
    return UpdateUpToDate(version: version, checkedAgo: _ago());
  }

  String _ago() {
    final at = _checkedAt;
    if (at == null) return 'just now';
    final minutes = _now().difference(at).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) {
      return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
    }
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }

  static String _failureText(CareFailed<UpdateCheck> failure) =>
      failure.message ??
      switch (failure.kind) {
        CareFailureKind.offline => "Can't reach Hermes.",
        _ => "Couldn't check for updates. Try again later.",
      };

  /// The Updates row's value and subtitle; null value when there is nothing
  /// to say (a managed install).
  ({String? value, String? subtitle}) rowText({String? fallbackVersion}) =>
      switch (status(fallbackVersion: fallbackVersion)) {
        null => (value: null, subtitle: null),
        UpdateChecking() => (value: 'Checking…', subtitle: null),
        UpdateUpToDate() => (value: 'Up to date', subtitle: null),
        UpdateCheckFailed() => (value: "Couldn't check", subtitle: null),
        UpdateAvailable(:final changeCount) ||
        UpdateRollback(:final changeCount?) => (
          value: 'Update available',
          subtitle: changeCount == 1 ? '1 change' : '$changeCount changes',
        ),
        UpdateRollback() => (value: 'Update available', subtitle: null),
        UpdateCannotApply() => (
          value: _check?.updateAvailable ?? false ? 'Update available' : null,
          subtitle: null,
        ),
      };

  /// The version a check last reported, for the status card.
  String? get version => _check?.currentVersion;

  List<UpdateChange> get changes => [
    for (final c in _check?.commits.take(20) ?? const <UpdateCommit>[])
      UpdateChange(summary: c.summary, byline: _byline(c)),
  ];

  String _byline(UpdateCommit c) {
    final at = c.at;
    final when = at == null ? null : _since(at);
    return [?c.author, ?when].join(' · ');
  }

  String _since(int unixSeconds) {
    final days = _now()
        .difference(DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000))
        .inDays;
    if (days < 1) return 'today';
    return days == 1 ? '1 day ago' : '$days days ago';
  }
}
