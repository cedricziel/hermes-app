import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../telemetry/breadcrumbs.dart';
import 'connector_operation_state.dart';
import 'gateway/gateway_rpc_client.dart';

typedef ConnectorRespond = Future<Map<String, Object?>> Function(
  Map<String, Object?> params,
);

class ConnectorResponseCanceled implements Exception {
  const ConnectorResponseCanceled();
}

/// Where the user's last answer to an operation stands.
///
/// `sending` ends within [ConnectorOperationController.responseBound]: the
/// response confirms (back to `idle`), or it is reported `unconfirmed` (the
/// call failed or had no result in time) or `refused` (the server answered
/// with a status other than ok). Both leave the actions offered again.
enum ConnectorAnswer { idle, sending, unconfirmed, refused }

/// How long a response may take before it is reported unconfirmed. The
/// transport ends the call later, after its own 30 second timeout.
const kConnectorResponseBound = Duration(seconds: 10);

class ConnectorOperationController extends ChangeNotifier {
  ConnectorOperationController({
    DateTime Function()? now,
    Future<bool> Function(Uri)? openBrowser,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
    this.responseBound = kConnectorResponseBound,
  }) : _now = now ?? DateTime.now,
       _openBrowser =
           openBrowser ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  final DateTime Function() _now;
  final Future<bool> Function(Uri) _openBrowser;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  final Duration responseBound;
  final _state = ConnectorOperationsState();
  final _pending = <ConnectorOperationKey>{},
      _accountAuthority = <ConnectorOperationKey>{};
  final _errors = <ConnectorOperationKey, String>{};
  final _answers = <ConnectorOperationKey, ConnectorAnswer>{};
  final _attempts = <ConnectorOperationKey, int>{};
  final _responseChecks = <ConnectorOperationKey, bool Function()>{};
  final _timers = <ConnectorOperationKey, Timer>{};
  Object? _attachment;
  String? _profile;
  ConnectorRespond? _respond;
  int _generation = 0;
  bool _disposed = false, _unsupported = false, _actionsAllowed = true;
  bool _displayOnly = false;
  bool hasScope(Object attachment) => !_disposed && _attachment == attachment;
  bool authorityFor(ConnectorOperationSnapshot operation) =>
      _actionsAllowed &&
      (_profile?.isNotEmpty ?? false) &&
      (operation.owner.type == 'session' ||
          _accountAuthority.contains(operation.key));
  List<ConnectorOperationSnapshot> get operations => _state.operations;
  Object? get attachment => _disposed ? null : _attachment;
  bool pendingFor(ConnectorOperationKey key) => _pending.contains(key);
  bool pendingResponseIsCurrent(
    ConnectorOperationSnapshot operation, {
    required Object attachment,
  }) =>
      _pending.contains(operation.key) &&
      _current(operation, attachment) &&
      (_responseChecks[operation.key]?.call() ?? false);
  String? errorFor(ConnectorOperationKey key) => _errors[key];

  /// Where the answer to [key] stands; `idle` when none was sent or it was
  /// confirmed.
  ConnectorAnswer answerFor(ConnectorOperationKey key) => _pending.contains(key)
      ? ConnectorAnswer.sending
      : _answers[key] ?? ConnectorAnswer.idle;

  /// Whether only the names, states and deadlines of the operations remain
  /// (see [suspend]): no link, no authority, no responder.
  bool get displayOnly => !_disposed && _displayOnly;

  void bind(
    Object? attachment, {
    String? profile,
    ConnectorRespond? respond,
    bool actionsAllowed = true,
  }) {
    if (_disposed) return;
    final hadResponder = _respond != null;
    _respond = respond;
    if (_attachment == attachment &&
        _profile == profile &&
        _actionsAllowed == actionsAllowed) {
      if (hadResponder != (_respond != null)) notifyListeners();
      return;
    }
    _generation++;
    _attachment = attachment;
    _profile = profile;
    _actionsAllowed = actionsAllowed;
    _unsupported = false;
    _displayOnly = false;
    _clear();
    if (attachment != null) _state.adopt(attachment);
    notifyListeners();
  }

  ConnectorSnapshotOutcome accept(
    ConnectorOperationSnapshot snapshot, {
    required Object attachment,
    bool accountProfileKnown = false,
  }) {
    if (_disposed) return ConnectorSnapshotOutcome.stale;
    final generation = _generation;
    final authorized =
        _actionsAllowed &&
        (_profile?.isNotEmpty ?? false) &&
        (snapshot.owner.type == 'session' ||
            accountProfileKnown ||
            _accountAuthority.contains(snapshot.key));
    final displayed = authorized
        ? snapshot
        : snapshot.copyWith(
            targets: List.unmodifiable(
              snapshot.targets.map((target) => target.withoutBrowserLink()),
            ),
          );
    final outcome = _state.apply(displayed, attachment: attachment);
    final accepted = _state.find(snapshot.key);
    _log(outcome.name);
    if (_disposed || generation != _generation || attachment != _attachment) {
      return ConnectorSnapshotOutcome.stale;
    }
    if (!identical(_state.find(snapshot.key), accepted)) {
      return ConnectorSnapshotOutcome.older;
    }
    if (outcome == ConnectorSnapshotOutcome.applied ||
        outcome == ConnectorSnapshotOutcome.enriched) {
      if (accountProfileKnown && authorized) {
        _accountAuthority.add(snapshot.key);
      }
      _timers.remove(snapshot.key)?.cancel();
      final current = _state.find(snapshot.key)!;
      if (current.settled) {
        _answers.remove(current.key);
        _errors.remove(current.key);
      }
      _armDeadline(current);
      notifyListeners();
    }
    return outcome;
  }

  /// Notifies when [operation]'s deadline passes, so a card that offered it
  /// stops. It carries no authority, so [suspend] arms it again.
  void _armDeadline(ConnectorOperationSnapshot operation) {
    _timers.remove(operation.key)?.cancel();
    final remaining = operation.deadlineAt.difference(_now());
    if (operation.settled || remaining <= Duration.zero) return;
    final generation = _generation;
    _timers[operation.key] = Timer(remaining, () {
      if (!_disposed && generation == _generation) {
        _log('deadline');
        if (!_disposed && generation == _generation) notifyListeners();
      }
    });
  }

  bool awaitingFinalStatus(ConnectorOperationKey key) {
    final operation = _state.find(key);
    return operation != null &&
        !operation.settled &&
        !_now().isBefore(operation.deadlineAt);
  }

  /// Whether [key] is unsettled and its deadline has not passed.
  bool stillOpen(ConnectorOperationKey key) {
    final operation = _state.find(key);
    return operation != null &&
        !operation.settled &&
        _now().isBefore(operation.deadlineAt);
  }

  bool _eligible(ConnectorOperationSnapshot? operation) =>
      operation != null &&
      _attachment != null &&
      !operation.settled &&
      _now().isBefore(operation.deadlineAt) &&
      authorityFor(operation);

  /// Whether a response could be sent for [key] but for one in flight, so a
  /// card keeps its actions on screen, disabled, while it is sending.
  bool offersRespond(ConnectorOperationKey key) =>
      !_unsupported && _respond != null && _eligible(_state.find(key));
  bool canRespond(ConnectorOperationKey key) =>
      offersRespond(key) && !_pending.contains(key);
  ConnectorOperationTarget? _target(ConnectorOperationKey key, String name) {
    final operation = _state.find(key);
    if (operation == null) return null;
    for (final target in operation.targets) {
      if (target.name == name) return target;
    }
    return null;
  }

  bool offersSkip(ConnectorOperationKey key, String name) =>
      offersRespond(key) && _target(key, name)?.supportsSkip == true;
  bool canSkip(ConnectorOperationKey key, String name) =>
      offersSkip(key, name) && !_pending.contains(key);
  bool offersOpen(ConnectorOperationKey key, String name) =>
      _eligible(_state.find(key)) && _target(key, name)?.browserUri != null;
  bool canOpen(ConnectorOperationKey key, String name) =>
      offersOpen(key, name) && !_pending.contains(key);
  bool _current(ConnectorOperationSnapshot operation, Object attachment) =>
      attachment == _attachment &&
      identical(_state.find(operation.key), operation);

  Future<void> skip(
    ConnectorOperationSnapshot operation,
    String name, {
    required Object attachment,
  }) async {
    if (!_current(operation, attachment) || !canSkip(operation.key, name)) {
      return;
    }
    _action('skip');
    if (!_current(operation, attachment) || !canSkip(operation.key, name)) {
      return;
    }
    await _answer(operation, {
      'targets': [
        {'name': name, 'status': 'skipped'},
      ],
    });
  }

  Future<void> continueOperation(
    ConnectorOperationSnapshot operation, {
    required Object attachment,
  }) async {
    if (!_current(operation, attachment) || !canRespond(operation.key)) return;
    _action('continue');
    if (!_current(operation, attachment) || !canRespond(operation.key)) return;
    await _answer(operation, {'targets': [], 'settled_by': 'continue'});
  }

  Future<void> _answer(
    ConnectorOperationSnapshot operation,
    Map<String, Object?> result,
  ) async {
    final generation = _generation,
        respond = _respond!,
        attachment = _attachment!,
        profile = _profile;
    final key = operation.key;
    final attempt = _attempts[key] = (_attempts[key] ?? 0) + 1;
    bool mine() =>
        !_disposed && generation == _generation && _attempts[key] == attempt;
    _responseChecks[key] = () =>
        !_disposed &&
        generation == _generation &&
        identical(respond, _respond) &&
        _current(operation, attachment) &&
        _eligible(operation) &&
        !_unsupported;
    _pending.add(key);
    _errors.remove(key);
    _answers.remove(key);
    try {
      notifyListeners();
      if (_disposed ||
          generation != _generation ||
          !identical(respond, _respond) ||
          !_current(operation, attachment) ||
          !_eligible(operation) ||
          _unsupported) {
        return;
      }
      final reply = respond({
        'owner': operation.owner.toWire(),
        'op_id': operation.opId,
        'profile': ?profile,
        'result': result,
      }).then<Object?>((value) => value, onError: _Failed.new);
      final bound = Completer<_Bound>();
      final timer = Timer(responseBound, () => bound.complete(const _Bound()));
      final first = await Future.any<Object?>([reply, bound.future]);
      timer.cancel();
      if (!mine()) return;
      if (first is _Bound) {
        _report(key, ConnectorAnswer.unconfirmed);
        // The transport ends the call on its own later; a settlement it may
        // still carry is applied, nothing else.
        unawaited(reply.then((late) => _lateResult(late, key, generation)));
        return;
      }
      if (first is _Failed) {
        final error = first.error;
        if (error is ConnectorResponseCanceled) {
          _log('stale');
          return;
        }
        if (error is GatewayRpcException &&
            error.code == kGatewayMethodNotFound) {
          _unsupported = true;
          _errors[key] = 'Connection responses are unavailable on this server.';
          _log('unsupported');
          return;
        }
        _report(key, ConnectorAnswer.unconfirmed);
        return;
      }
      final response = first as Map<String, Object?>;
      if (response['status'] != 'ok') {
        _report(key, ConnectorAnswer.refused);
      } else if (response['settled'] is! bool) {
        _report(key, ConnectorAnswer.unconfirmed);
      } else {
        if (response['settled'] == true) {
          _state.markSettled(key);
          _timers.remove(key)?.cancel();
        }
        _log('responded');
      }
    } finally {
      if (mine()) {
        _responseChecks.remove(key);
        _pending.remove(key);
        notifyListeners();
      }
    }
  }

  /// Notes that the answer to [key] was refused or left unconfirmed, with
  /// the words the older cards show and the outcome to log.
  void _report(ConnectorOperationKey key, ConnectorAnswer answer) {
    _answers[key] = answer;
    _errors[key] = answer == ConnectorAnswer.refused
        ? 'The server refused your answer.'
        : "Couldn't confirm your answer. It may have gone through; check "
              'before trying again.';
    _log(answer.name);
  }

  /// What the call returned after it was reported unconfirmed: a settlement
  /// still settles the operation, anything else changes nothing and logs
  /// nothing.
  void _lateResult(Object? late, ConnectorOperationKey key, int generation) {
    if (_disposed ||
        generation != _generation ||
        late is! Map ||
        late['status'] != 'ok' ||
        late['settled'] is! bool) {
      return;
    }
    // It did go through: the line that said it might not have is stale.
    _answers.remove(key);
    _errors.remove(key);
    if (late['settled'] == true) {
      _state.markSettled(key);
      _timers.remove(key)?.cancel();
    }
    notifyListeners();
  }

  Future<void> openTarget(
    ConnectorOperationSnapshot operation,
    String name, {
    required Object attachment,
  }) async {
    if (!_current(operation, attachment) || !canOpen(operation.key, name)) {
      return;
    }
    final uri = _target(operation.key, name)!.browserUri!;
    final generation = _generation;
    _action('browser');
    if (_disposed ||
        generation != _generation ||
        !_current(operation, attachment) ||
        !canOpen(operation.key, name)) {
      return;
    }
    try {
      final opened = await _openBrowser(uri);
      if (_disposed ||
          generation != _generation ||
          !_current(operation, attachment)) {
        return;
      }
      if (!opened) _errors[operation.key] = 'Could not open the browser.';
      _log(opened ? 'browser_opened' : 'browser_failed');
    } on Object {
      if (_disposed ||
          generation != _generation ||
          !_current(operation, attachment)) {
        return;
      }
      _errors[operation.key] = 'Could not open the browser.';
      _log('browser_failed');
    }
    if (!_disposed && generation == _generation) notifyListeners();
  }

  void detailsOpened() => _action('details');
  void _action(String action) => breadcrumbs('chat.visibility_action', {
    'feature': 'connector_operations',
    'action': action,
  });
  void _log(String outcome) {
    try {
      events('gateway.visibility_outcome', {
        'feature': 'connector_operations',
        'outcome': outcome,
      });
    } on Object {
      return;
    }
  }

  /// Keeps what a card shows (target names, states, the deadline) and drops
  /// everything that acts, because the connection is lost: no browser link,
  /// no authority and no responder, and an answer in flight is abandoned. The
  /// reconnect replay builds a new controller; retirement disposes this one.
  void suspend() {
    if (_disposed || _displayOnly) return;
    _generation++;
    _displayOnly = true;
    _actionsAllowed = false;
    _respond = null;
    _unsupported = false;
    _pending.clear();
    _responseChecks.clear();
    _errors.clear();
    _answers.clear();
    _attempts.clear();
    _accountAuthority.clear();
    _state.stripBrowserLinks();
    for (final operation in _state.operations) {
      _armDeadline(operation);
    }
    notifyListeners();
  }

  void _clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pending.clear();
    _responseChecks.clear();
    _errors.clear();
    _answers.clear();
    _attempts.clear();
    _accountAuthority.clear();
    _state.clear();
  }

  int _notificationDepth = 0;

  @override
  void notifyListeners() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _clear();
    if (_notificationDepth == 0) super.dispose();
  }
}

/// The bound passed with no outcome.
class _Bound {
  const _Bound();
}

/// A response call that threw.
class _Failed {
  const _Failed(this.error);
  final Object error;
}
