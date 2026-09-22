import 'dart:async';

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

    tearDown(() => results.close());

    ConnectivityNetworkSignals signals({bool reportsVpn = true}) =>
        ConnectivityNetworkSignals(
          results: results.stream,
          check: () async => current,
          reportsVpn: reportsVpn,
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
