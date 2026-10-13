import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../auth/auth_controller.dart';
import '../notifications/notification_service.dart';
import 'background_check_status.dart';
import 'background_scheduler.dart';

class BackgroundCheckController extends ChangeNotifier
    with WidgetsBindingObserver {
  BackgroundCheckController({
    required this._changes,
    required this._account,
    required this._signedOut,
    required this._permission,
    BackgroundCheckStore? store,
    BackgroundRefreshStatus? refreshStatus,
    PeriodicTasks? tasks,
    Future<String> Function()? name,
    TargetPlatform? platform,
    this._observeLifecycle = true,
  }) : _store = store ?? BackgroundCheckStore(),
       _refreshStatus = refreshStatus ?? ChannelRefreshStatus(),
       _tasks = tasks ?? WorkmanagerTasks(),
       _name = name ?? backgroundRefreshName,
       platform = platform ?? defaultTargetPlatform;
  factory BackgroundCheckController.forAuth(
    AuthController auth,
    NotificationService notifications,
  ) => BackgroundCheckController(
    changes: auth,
    account: () =>
        auth.state == HermesConnectionState.ready ? auth.accountKey : null,
    signedOut: auth.signedOut,
    permission: notifications.allowed,
  );
  final Listenable _changes;
  final String? Function() _account;
  final Stream<void> _signedOut;
  final Future<bool?> Function() _permission;
  final BackgroundCheckStore _store;
  final BackgroundRefreshStatus _refreshStatus;
  final PeriodicTasks _tasks;
  final Future<String> Function() _name;
  final TargetPlatform platform;
  final bool _observeLifecycle;
  StreamSubscription<void>? _ended;
  Future<void> _identityWork = Future.value();
  String? _currentAccount;
  var _generation = 0;
  var _disposed = false;
  bool? permission;
  String? capability;
  BackgroundCheckStatus? status;
  bool get supported =>
      !kIsWeb &&
      (platform == TargetPlatform.iOS || platform == TargetPlatform.android);
  void start() {
    if (!supported) {
      return;
    }
    _changes.addListener(_onAuth);
    _ended = _signedOut.listen((_) {
      _currentAccount = null;
      _generation++;
      status = null;
      _identityWork = _identityWork.then((_) => _store.clear());
      notifyListeners();
    });
    if (_observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    _onAuth();
  }

  void _onAuth() {
    final account = _account();
    if (account == _currentAccount) {
      return;
    }
    if (account == null) {
      _currentAccount = null;
      _generation++;
      status = null;
      notifyListeners();
      return;
    }
    _currentAccount = account;
    _generation++;
    status = null;
    _identityWork = _identityWork.then((_) => _store.activate(account));
    notifyListeners();
    if (!_disposed && _currentAccount == account && _account() == account) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    if (!supported || _disposed) {
      return;
    }
    final generation = ++_generation;
    final account = _account();
    await _identityWork;
    bool? allowed;
    String? available;
    try {
      allowed = await _permission();
    } on Object {
      allowed = null;
    }
    try {
      if (platform == TargetPlatform.iOS) {
        available = await _refreshStatus.read();
      } else {
        final registered = await _tasks.isScheduled(await _name());
        available = registered == null
            ? null
            : registered
            ? 'registered'
            : 'notRegistered';
      }
    } on Object {
      available = null;
    }
    final record = account == null ? null : await _store.read(account);
    if (_disposed || generation != _generation || account != _account()) {
      return;
    }
    permission = allowed;
    capability = available;
    status = record;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (supported) {
      _changes.removeListener(_onAuth);
      unawaited(_ended?.cancel());
      if (_observeLifecycle) {
        WidgetsBinding.instance.removeObserver(this);
      }
    }
    super.dispose();
  }
}
