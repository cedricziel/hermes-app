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

class ConnectorOperationController extends ChangeNotifier {
  ConnectorOperationController({
    DateTime Function()? now,
    Future<bool> Function(Uri)? openBrowser,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  }) : _now = now ?? DateTime.now,
       _openBrowser =
           openBrowser ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  final DateTime Function() _now;
  final Future<bool> Function(Uri) _openBrowser;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  final _state = ConnectorOperationsState();
  final _pending = <ConnectorOperationKey>{},
      _accountAuthority = <ConnectorOperationKey>{};
  final _errors = <ConnectorOperationKey, String>{};
  final _timers = <ConnectorOperationKey, Timer>{};
  Object? _attachment;
  String? _profile;
  ConnectorRespond? _respond;
  int _generation = 0;
  bool _disposed = false, _unsupported = false, _actionsAllowed = true;
  bool hasScope(Object attachment) => !_disposed && _attachment == attachment;
  bool authorityFor(ConnectorOperationSnapshot operation) =>
      _actionsAllowed &&
      (_profile?.isNotEmpty ?? false) &&
      (operation.owner.type == 'session' ||
          _accountAuthority.contains(operation.key));
  List<ConnectorOperationSnapshot> get operations => _state.operations;
  Object? get attachment => _disposed ? null : _attachment;
  bool pendingFor(ConnectorOperationKey key) => _pending.contains(key);
  String? errorFor(ConnectorOperationKey key) => _errors[key];

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
    if (outcome == ConnectorSnapshotOutcome.applied) {
      if (accountProfileKnown && authorized) {
        _accountAuthority.add(snapshot.key);
      }
      _timers.remove(snapshot.key)?.cancel();
      final current = _state.find(snapshot.key)!;
      final remaining = current.deadlineAt.difference(_now());
      if (!current.settled && remaining > Duration.zero) {
        final generation = _generation;
        _timers[current.key] = Timer(remaining, () {
          if (!_disposed && generation == _generation) {
            _log('deadline');
            if (!_disposed && generation == _generation) notifyListeners();
          }
        });
      }
      notifyListeners();
    }
    return outcome;
  }

  bool awaitingFinalStatus(ConnectorOperationKey key) {
    final operation = _state.find(key);
    return operation != null &&
        !operation.settled &&
        !_now().isBefore(operation.deadlineAt);
  }

  bool _eligible(ConnectorOperationSnapshot? operation) =>
      operation != null &&
      _attachment != null &&
      !operation.settled &&
      _now().isBefore(operation.deadlineAt) &&
      authorityFor(operation);
  bool canRespond(ConnectorOperationKey key) =>
      !_unsupported &&
      _respond != null &&
      !_pending.contains(key) &&
      _eligible(_state.find(key));
  ConnectorOperationTarget? _target(ConnectorOperationKey key, String name) {
    final operation = _state.find(key);
    if (operation == null) return null;
    for (final target in operation.targets) {
      if (target.name == name) return target;
    }
    return null;
  }

  bool canSkip(ConnectorOperationKey key, String name) =>
      canRespond(key) && _target(key, name)?.supportsSkip == true;
  bool canOpen(ConnectorOperationKey key, String name) =>
      !_pending.contains(key) &&
      _eligible(_state.find(key)) &&
      _target(key, name)?.browserUri != null;
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
    _pending.add(key);
    _errors.remove(key);
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
      final response = await respond({
        'owner': operation.owner.toWire(),
        'op_id': operation.opId,
        'profile': ?profile,
        'result': result,
      });
      if (_disposed || generation != _generation) return;
      if (response['status'] != 'ok' || response['settled'] is! bool) {
        _errors[key] = 'The server did not confirm the response.';
        _log('refused');
      } else {
        if (response['settled'] == true) {
          _state.markSettled(key);
          _timers.remove(key)?.cancel();
        }
        _log('responded');
      }
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _unsupported =
          error is GatewayRpcException && error.code == kGatewayMethodNotFound;
      _errors[key] = _unsupported
          ? 'Connection responses are unavailable on this server.'
          : 'The response was refused or the connection was lost.';
      _log(_unsupported ? 'unsupported' : 'refused');
    } finally {
      if (!_disposed && generation == _generation) {
        _pending.remove(key);
        notifyListeners();
      }
    }
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

  void _clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pending.clear();
    _errors.clear();
    _accountAuthority.clear();
    _state.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _clear();
    super.dispose();
  }
}
