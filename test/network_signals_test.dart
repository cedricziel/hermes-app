import 'dart:async';
import 'dart:io' show SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/network/network_signals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('debounced turns a burst into one event after the quiet period', () {
    fakeAsync((async) {
      final source = StreamController<int>();
      final seen = <int>[];
      debounced(source.stream, const Duration(seconds: 1)).listen(seen.add);

      source
        ..add(1)
        ..add(2);
      async.elapse(const Duration(milliseconds: 500));
      source.add(3);
      async.elapse(const Duration(milliseconds: 999));
      expect(seen, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(seen, [3]);

      source.add(4);
      async.elapse(const Duration(seconds: 2));
      expect(seen, [3, 4]);
      unawaited(source.close());
    });
  });

  group('ConnectivityNetworkSignals', () {
    late StreamController<List<ConnectivityResult>> results;
    late List<ConnectivityResult> current;

    setUp(() {
      results = StreamController<List<ConnectivityResult>>();
      current = [ConnectivityResult.wifi];
    });

    tearDown(() => unawaited(results.close()));

    ConnectivityNetworkSignals signals({
      bool reportsVpn = true,
      bool onLinux = false,
    }) => ConnectivityNetworkSignals(
      results: results.stream,
      check: () async => current,
      reportsVpn: reportsVpn,
      onLinux: onLinux,
      debounce: const Duration(milliseconds: 10),
    );

    test('emits a change when the connection changes', () async {
      final s = signals();
      addTearDown(s.dispose);
      final changes = s.changes.first;

      results.add([ConnectivityResult.mobile]);

      await changes.timeout(const Duration(seconds: 2));
    });

    test('emits a change when the app returns to the foreground', () async {
      final s = signals();
      addTearDown(s.dispose);
      final changes = s.changes.first;

      s.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await changes.timeout(const Duration(seconds: 2));
    });

    test(
      'reports whether a VPN is active where the platform can tell',
      () async {
        current = [ConnectivityResult.wifi, ConnectivityResult.vpn];
        final s = signals();
        addTearDown(s.dispose);
        s.changes.listen((_) {});
        await pumpEventQueue();
        expect(s.vpnActive, isTrue);

        results.add([ConnectivityResult.wifi]);
        await pumpEventQueue();
        expect(s.vpnActive, isFalse);
      },
    );

    test('on Linux without a system bus it never touches connectivity but still nudges on resume', () async {
      var checks = 0;
      final s = ConnectivityNetworkSignals(
        results: results.stream,
        check: () async {
          checks++;
          return current;
        },
        onLinux: true,
        hasSystemBus: () => false,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(s.dispose);
      final changes = s.changes.first;

      expect(results.hasListener, isFalse);
      results.add([ConnectivityResult.mobile]);
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await changes.timeout(const Duration(seconds: 2));
      expect(checks, 0);
      expect(s.vpnActive, isNull);
    });

    test('on Linux with a system bus it subscribes and checks', () async {
      var checks = 0;
      final s = ConnectivityNetworkSignals(
        results: results.stream,
        check: () async {
          checks++;
          return current;
        },
        onLinux: true,
        hasSystemBus: () => true,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(s.dispose);
      final changes = s.changes.first;

      expect(results.hasListener, isTrue);
      results.add([ConnectivityResult.mobile]);

      await changes.timeout(const Duration(seconds: 2));
      expect(checks, 1);
    });

    test('on Linux a plugin that throws on listen leaves no uncaught error and resume still nudges', () async {
      final broken = StreamController<List<ConnectivityResult>>(
        onListen: () => throw const SocketException('no NetworkManager'),
      );
      final s = ConnectivityNetworkSignals(
        results: broken.stream,
        check: () async => throw StateError('no NetworkManager'),
        onLinux: true,
        hasSystemBus: () => true,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(s.dispose);
      addTearDown(() => unawaited(broken.close()));
      final changes = s.changes.first;
      await pumpEventQueue();

      s.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await changes.timeout(const Duration(seconds: 2));
    });

    ConnectivityNetworkSignals linuxSignals(
      Future<List<ConnectivityResult>> Function() check,
    ) => ConnectivityNetworkSignals(
      results: results.stream,
      check: check,
      onLinux: true,
      hasSystemBus: () => true,
      debounce: const Duration(milliseconds: 10),
    );

    test('on Linux a bus error from the plugin is swallowed', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final s = linuxSignals(() {
          Future<void>(() => throw const SocketException('dead bus'));
          return Future.value(current);
        });
        addTearDown(s.dispose);
        await pumpEventQueue();
      }, (error, _) => uncaught.add(error));
      expect(uncaught, isEmpty);
    });

    test('on Linux any other error reaches the parent zone', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final s = linuxSignals(() {
          Future<void>(() => throw StateError('a bug'));
          return Future.value(current);
        });
        addTearDown(s.dispose);
        await pumpEventQueue();
      }, (error, _) => uncaught.add(error));
      expect(uncaught.single, isA<StateError>());
    });

    test('on Linux a check that never answers is given up on', () {
      fakeAsync((async) {
        final s = linuxSignals(
          () => Completer<List<ConnectivityResult>>().future,
        );
        expect(async.pendingTimers, isNotEmpty);

        async.elapse(kLinuxCheckTimeout);

        expect(async.pendingTimers, isEmpty);
        s.dispose();
      });
    });

    group('linuxSystemBusAvailable', () {
      bool check(Map<String, String> env, Set<String> files) =>
          linuxSystemBusAvailable(environment: env, exists: files.contains);

      test('is false with no address and no socket', () {
        expect(check({}, {}), isFalse);
        expect(check({'DBUS_SYSTEM_BUS_ADDRESS': ''}, {}), isFalse);
      });

      test('is true with an address or either socket', () {
        expect(check({'DBUS_SYSTEM_BUS_ADDRESS': 'unix:path=/x'}, {}), isTrue);
        expect(check({}, {'/var/run/dbus/system_bus_socket'}), isTrue);
        expect(check({}, {'/run/dbus/system_bus_socket'}), isTrue);
      });
    });

    test('does not know about a VPN where the platform cannot tell', () async {
      current = [ConnectivityResult.vpn];
      final s = signals(reportsVpn: false);
      addTearDown(s.dispose);
      s.changes.listen((_) {});
      await pumpEventQueue();
      expect(s.vpnActive, isNull);
    });
  });
}
