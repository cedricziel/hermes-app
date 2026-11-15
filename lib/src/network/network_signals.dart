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

/// Whether [error] comes from the D-Bus connection: a socket error, an
/// exception of the `dbus` package (matched by name, since it is not a direct
/// dependency; this is what a bus without NetworkManager throws), or one of
/// the plain strings and address `FormatException`s it throws for a
/// malformed address. An unrelated
/// `TimeoutException` is not one.
bool isLinuxBusError(Object error) =>
    error is SocketException ||
    // The dbus package is the only thing in these zones that throws raw
    // Strings. Its address parser throws FormatExceptions naming the "D-Bus
    // address"; any other FormatException (a corrupt JSON file read by the
    // notification plugin, say) is not a bus error.
    error is String ||
    (error is FormatException && error.message.contains('D-Bus address')) ||
    error.runtimeType.toString().startsWith('DBus');

/// An address the `dbus` package can open. It reads the whole value as one
/// address (no `;` list) and opens only `unix:` with a `path=` or `abstract=`
/// and `tcp:` with a `host=`, a numeric `port=` and, if given, `family=` ipv4
/// or ipv6; every property must be `key=value`. Anything else (such as the
/// `disabled:` that switches D-Bus off) makes the package throw, so the plugin
/// is not started for it.
bool usableBusAddress(String address) {
  Map<String, String>? props(String rest) {
    final out = <String, String>{};
    for (final p in rest.split(',')) {
      final eq = p.indexOf('=');
      if (eq <= 0) return null;
      out[p.substring(0, eq)] = p.substring(eq + 1);
    }
    return out;
  }

  if (address.startsWith('unix:')) {
    final p = props(address.substring(5));
    return p != null &&
        ((p['path']?.isNotEmpty ?? false) ||
            (p['abstract']?.isNotEmpty ?? false));
  }
  if (address.startsWith('tcp:')) {
    final p = props(address.substring(4));
    final family = p?['family'];
    return p != null &&
        (p['host']?.isNotEmpty ?? false) &&
        int.tryParse(p['port'] ?? '') != null &&
        (family == null || family == 'ipv4' || family == 'ipv6');
  }
  return false;
}

/// Whether a D-Bus system bus can exist: `DBUS_SYSTEM_BUS_ADDRESS` is set, or
/// one of the usual sockets is there.
bool linuxSystemBusAvailable({
  Map<String, String>? environment,
  bool Function(String path)? exists,
}) {
  if ((environment ?? Platform.environment)['DBUS_SYSTEM_BUS_ADDRESS']
      case final address?) {
    return usableBusAddress(address);
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
        () => _listen(results, check),
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
    Future<List<ConnectivityResult>> Function()? check,
  ) {
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
