import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// What the app learns about the device's network. It is a nudge to check
/// again, never proof that a server can or cannot be reached.
abstract class NetworkSignals {
  /// Fires, once per burst, when the connection changed or the app came back
  /// to the foreground.
  Stream<void> get changes;

  /// Whether a VPN is active, or null where the platform cannot tell.
  bool? get vpnActive;
}

class NoNetworkSignals implements NetworkSignals {
  const NoNetworkSignals();

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  bool? get vpnActive => null;
}

/// Emits [source]'s latest event once it has been quiet for [quiet].
Stream<T> debounced<T>(Stream<T> source, Duration quiet) {
  Timer? timer;
  StreamSubscription<T>? subscription;
  late final StreamController<T> out;
  out = StreamController<T>(
    onListen: () {
      subscription = source.listen(
        (event) {
          timer?.cancel();
          timer = Timer(quiet, () => out.add(event));
        },
        onError: out.addError,
        onDone: out.close,
      );
    },
    onCancel: () {
      timer?.cancel();
      return subscription?.cancel();
    },
  );
  return out.stream;
}

/// [NetworkSignals] from `connectivity_plus` and the app lifecycle. Only
/// Android and Windows report a VPN; iOS and macOS report `other` for it.
class ConnectivityNetworkSignals
    with WidgetsBindingObserver
    implements NetworkSignals {
  ConnectivityNetworkSignals({
    Stream<List<ConnectivityResult>>? results,
    Future<List<ConnectivityResult>> Function()? check,
    bool? reportsVpn,
    Duration debounce = const Duration(seconds: 1),
  }) : _reportsVpn = reportsVpn ?? (Platform.isAndroid || Platform.isWindows) {
    final connectivity = results == null || check == null
        ? Connectivity()
        : null;
    _subscription = (results ?? connectivity!.onConnectivityChanged).listen((
      current,
    ) {
      _update(current);
      _raw.add(null);
    }, onError: (Object _) {});
    (check ?? connectivity!.checkConnectivity)().then(_update, onError: (_) {});
    WidgetsBinding.instance.addObserver(this);
    changes = debounced(_raw.stream, debounce);
  }

  final bool _reportsVpn;
  final _raw = StreamController<void>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool? _vpnActive;

  @override
  late final Stream<void> changes;

  @override
  bool? get vpnActive => _vpnActive;

  void _update(List<ConnectivityResult> current) {
    if (_reportsVpn) _vpnActive = current.contains(ConnectivityResult.vpn);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _raw.add(null);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    _raw.close();
  }
}
