import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'attention.dart';
import 'care_result.dart';
import 'server_attention_mark.dart';
import 'server_care_repository.dart';
import 'server_status.dart';

/// The parts of the Server screen that hide themselves when the server lacks
/// their route.
enum CarePart { status, update, logs, check, usage }

/// The latest server status for the chat's profile, and what it says needs
/// attention. One per connection, owned by the shell.
///
/// It reads on open, on [refresh], when the app resumes (at most every
/// [resumeInterval] otherwise), and on a profile switch; an answer to an
/// earlier read is dropped. While App Lock covers the app nothing is read.
class ServerCareController extends ChangeNotifier with SafeNotifier {
  ServerCareController({
    required this.repository,
    this.telemetry = const ConnectionTelemetry(),
    this.covered,
    DateTime Function()? now,
    this.resumeInterval = const Duration(minutes: 5),
    String? profile,
  }) : _now = now ?? DateTime.now,
       // A named parameter cannot be a private initializing formal.
       // ignore: prefer_initializing_formals
       _profile = profile;

  final ServerCareRepository repository;
  final ConnectionTelemetry telemetry;

  /// Whether App Lock covers the app; the status is not read then.
  final bool Function()? covered;
  final Duration resumeInterval;
  final DateTime Function() _now;

  ServerStatus? _status;
  CareFailureKind? _failure;
  bool _loading = false;
  bool _supported = true;
  bool _gatewayBusy = false;
  bool _updating = false;
  bool _restarting = false;
  String? _profile;
  DateTime? _lastRead;
  int _generation = 0;
  bool _missedWhileCovered = false;
  bool _profileLookupFailed = false;
  final _reportedUnsupported = <CarePart>{};

  /// The chat's profile this controller reads for; null until one is known.
  String? get profile => _profile;

  /// Whether the server has the route of [part], as far as it is known: true
  /// until a read of it was answered with a missing route.
  bool offers(CarePart part) => !_reportedUnsupported.contains(part);

  /// Whether no profile is known and looking one up failed: the status cannot
  /// be read until it is tried again.
  bool get profileLookupFailed => _profileLookupFailed && _profile == null;

  /// Set by the shell: looks up the server's default profile again. A read
  /// asked for while no profile is known does this instead.
  Future<void> Function()? lookUpProfile;

  /// The shell's lookup of the default profile ended without a name.
  void profileLookupEnded({required bool found}) {
    final failed = !found && _profile == null;
    if (failed == _profileLookupFailed) return;
    _profileLookupFailed = failed;
    notifyListeners();
  }

  /// The last status read, kept while a later read fails.
  ServerStatus? get status => _status;

  /// Why the last read failed; null when it succeeded or none ran.
  CareFailureKind? get failure => _failure;
  bool get loading => _loading;

  /// False once the server answered that it has no status route.
  bool get supported => _supported;

  /// The headline's state; null until a read answered, or when the server
  /// has no status route or failed in a way that says nothing about it.
  Attention? get attention {
    if (!_supported) return null;
    if (_failure == CareFailureKind.offline) return Attention.offline;
    // Any other failed read says nothing new: the old status is not shown as
    // current, and no mark is raised or cleared on it.
    if (_failure != null) return null;
    final status = _status;
    if (status == null) return null;
    return Attention.of(status, gatewayBusy: _gatewayBusy);
  }

  ServerAttentionMark get mark => ServerAttentionMark.of(
    attention: attention,
    updating: _updating,
    restarting: _restarting,
  );

  /// A gateway restart or start is running: the headline stops offering it.
  set gatewayBusy(bool value) => _set(() => _gatewayBusy = value);

  /// An update is running or checking its result.
  set updating(bool value) => _set(() => _updating = value);

  /// Hermes is restarting; the Mac sidebar says so.
  set restarting(bool value) => _set(() => _restarting = value);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// Follows the chat's profile; a change reads again, and an answer still
  /// on its way for the old one is dropped. While no profile is known nothing
  /// is read and there is no mark: a read without a profile would answer for
  /// whichever profile the server has active.
  void profileChanged(String? profile) {
    if (profile == _profile) return;
    _profile = profile;
    _generation++;
    _status = null;
    _failure = null;
    _lastRead = null;
    // The gateway that was busy belonged to the old profile.
    _gatewayBusy = false;
    if (profile == null) {
      // Nothing to read, and a read that was running is dropped.
      _loading = false;
      notifyListeners();
      return;
    }
    refresh();
  }

  /// Reads the status now.
  Future<void> refresh() async {
    final profile = _profile;
    if (disposed) return;
    if (profile == null) {
      // Nothing can be read before a profile is known; try to learn one.
      final lookUp = lookUpProfile;
      if (lookUp != null) {
        _profileLookupFailed = false;
        notifyListeners();
        await lookUp();
      }
      return;
    }
    if (covered?.call() ?? false) {
      // A read that was running is dropped below; do not leave it spinning.
      // The one that is skipped is made up for on unlock.
      _loading = false;
      _missedWhileCovered = true;
      notifyListeners();
      return;
    }
    _missedWhileCovered = false;
    final generation = ++_generation;
    _loading = true;
    notifyListeners();
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'server_care.status.fetch',
        attributes: telemetry.serverAttributes,
      ),
    );
    var outcome = 'obsolete';
    try {
      final result = await repository.status(profile: profile);
      if (generation != _generation || disposed) return;
      switch (result) {
        case CareOk(:final value):
          _lastRead = _now();
          _status = value;
          _failure = null;
          _supported = true;
          outcome = 'success';
        case CareUnsupported():
          _lastRead = _now();
          _status = null;
          _failure = null;
          _supported = false;
          outcome = 'unsupported';
          reportUnsupported(CarePart.status);
        case CareFailed(:final kind):
          // The next resume tries again, also after an earlier success.
          _lastRead = null;
          _failure = kind;
          outcome = kind.name;
      }
    } finally {
      _quiet(() => span?.setAttribute('outcome', outcome));
      _quiet(() => span?.end());
      if (generation == _generation && !disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// The app came back to the front: read again unless a read is recent. Dart
  /// timers stop while iOS suspends the app, so this is what catches up.
  Future<void> resumed() async {
    if (_loading) return;
    // A read skipped under App Lock is owed, however recent the last was.
    if (_missedWhileCovered) return refresh();
    final last = _lastRead;
    if (last != null && _now().difference(last) < resumeInterval) return;
    await refresh();
  }

  /// Logs once per part and connection that the server lacks a route. The
  /// part is a fixed name; nothing about the server goes in the event.
  void reportUnsupported(CarePart part) {
    if (!_reportedUnsupported.add(part)) return;
    notifyListeners();
    _quiet(
      () => telemetry.events('server_care.unsupported', {'part': part.name}),
    );
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
