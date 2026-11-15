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

/// How long the first connectivity check may take on Linux.
const kLinuxCheckTimeout = Duration(seconds: 5);

/// Whether [error] comes from the D-Bus connection: a socket or OS error, an
/// exception of the `dbus` package (matched by name, since it is not a direct
/// dependency; this is what a bus without NetworkManager throws), or one of
/// the plain strings it throws from opening a socket. An unrelated
/// `TimeoutException` is not one; the bounded check handles its own.
bool isLinuxBusError(Object error) =>
    error is SocketException ||
    error is OSError ||
    (error is String &&
        (error.startsWith('D-Bus') ||
            error.startsWith('Unable to determine D-Bus'))) ||
    error.runtimeType.toString().startsWith('DBus');

/// Whether a D-Bus system bus can exist: `DBUS_SYSTEM_BUS_ADDRESS` is set, or
/// one of the usual sockets is there.
bool linuxSystemBusAvailable({
  Map<String, String>? environment,
  bool Function(String path)? exists,
}) {
  if ((environment ?? Platform.environment)['DBUS_SYSTEM_BUS_ADDRESS']
      case final address? when address.isNotEmpty) {
    return true;
  }
  final present = exists ?? _socketExists;
  return present('/var/run/dbus/system_bus_socket') ||
      present('/run/dbus/system_bus_socket');
}

bool _socketExists(String path) {
  try {
    return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
  } on Object {
    return false;
  }
}

/// [NetworkSignals] from `connectivity_plus` and the app lifecycle. Only
/// Android and Windows report a VPN; iOS and macOS report `other` for it.
///
/// On Linux the plugin talks to NetworkManager over the system D-Bus. It is
/// not created at all when there is no system bus ([hasSystemBus]; containers,
/// headless setups), and with one it is started inside an error zone, because
/// the plugin rethrows from inside its stream's `onListen`, where no `onError`
/// reaches. A bus without NetworkManager then degrades to the lifecycle nudge.
/// The app reads a VPN only on Android and Windows, though the plugin reports
/// one on Linux too. [results] and [check] are ignored when there is no bus.
class ConnectivityNetworkSignals
    with WidgetsBindingObserver
    implements NetworkSignals {
  ConnectivityNetworkSignals({
    Stream<List<ConnectivityResult>>? results,
    Future<List<ConnectivityResult>> Function()? check,
    bool? reportsVpn,
    bool? onLinux,
    bool Function()? hasSystemBus,
    Duration debounce = const Duration(seconds: 1),
  }) : _reportsVpn = reportsVpn ?? (Platform.isAndroid || Platform.isWindows) {
    final linux = onLinux ?? Platform.isLinux;
    if (!linux) {
      _listen(results, check);
    } else if ((hasSystemBus ?? linuxSystemBusAvailable)()) {
      // Only bus errors end here: the zone holds the plugin's stream for as
      // long as it lives, so any other error goes on to the parent zone.
      runZoned(
        () => _listen(results, check, bounded: true),
        zoneSpecification: ZoneSpecification(
          handleUncaughtError: (self, parent, zone, error, stack) {
            if (!isLinuxBusError(error)) {
              parent.handleUncaughtError(zone, error, stack);
            }
          },
        ),
      );
    }
    WidgetsBinding.instance.addObserver(this);
    changes = debounced(_raw.stream, debounce);
  }

  void _listen(
    Stream<List<ConnectivityResult>>? results,
    Future<List<ConnectivityResult>> Function()? check, {
    bool bounded = false,
  }) {
    final connectivity = results == null || check == null
        ? Connectivity()
        : null;
    _subscription = (results ?? connectivity!.onConnectivityChanged).listen((
      current,
    ) {
      _update(current);
      _raw.add(null);
    }, onError: (Object _) {});
    // The plugin's D-Bus client never answers once its connection failed.
    var pending = (check ?? connectivity!.checkConnectivity)();
    if (bounded) pending = pending.timeout(kLinuxCheckTimeout);
    pending.then(_update, onError: (_) {});
  }

  final bool _reportsVpn;
  final _raw = StreamController<void>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
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
    _subscription?.cancel();
    _raw.close();
  }
}
