import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/background/app_presence.dart';
import 'package:hermes_app/src/background/background_scheduler.dart';

class _Tasks implements PeriodicTasks {
  final calls = <String>[];
  Exception? registerFailure;

  /// What [isScheduled] answers; null is "cannot tell".
  bool? scheduled = true;

  /// Holds back [initialize] until it completes.
  Completer<void>? initializeGate;

  @override
  Future<void> initialize(Function dispatcher) async {
    calls.add('initialize');
    await initializeGate?.future;
  }

  @override
  Future<bool?> isScheduled(String name) async => scheduled;

  @override
  Future<void> register(String name, {required Duration interval}) async {
    if (registerFailure case final error?) throw error;
    calls.add('register $name ${interval.inMinutes}m');
  }

  @override
  Future<void> cancel(String name) async => calls.add('cancel $name');
}

class _Status implements BackgroundRefreshStatus {
  _Status(this.value);

  final String? value;
  var reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    return value;
  }
}

class _Connection extends ChangeNotifier {
  var state = HermesConnectionState.initializing;
  // Closed by the test's tearDown.
  // ignore: close_sinks
  final ended = StreamController<void>.broadcast(sync: true);

  void moveTo(HermesConnectionState next) {
    state = next;
    notifyListeners();
  }
}

void _dispatcher() {}

void main() {
  late _Tasks tasks;
  late _Connection connection;
  late List<(String, Map<String, Object>)> events;

  setUp(() {
    tasks = _Tasks();
    connection = _Connection();
    events = [];
    addTearDown(connection.ended.close);
  });

  BackgroundScheduler scheduler(
    TargetPlatform platform, {
    BackgroundRefreshStatus? status,
    AppPresence? presence,
  }) => BackgroundScheduler(
    changes: connection,
    state: () => connection.state,
    ended: connection.ended.stream,
    tasks: tasks,
    platform: platform,
    name: () async => 'hermes.refresh',
    dispatcher: _dispatcher,
    events: (name, [attributes = const {}]) => events.add((name, attributes)),
    status: status,
    presence: presence ?? AppPresence(name: 'test-presence-${platform.name}'),
    observeLifecycle: false,
  )..start();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('on $platform', () {
      test('registers the periodic run once signed in', () async {
        final started = scheduler(platform);
        await settle();
        expect(tasks.calls, isEmpty);

        connection.moveTo(HermesConnectionState.ready);
        await settle();

        expect(tasks.calls, ['initialize', 'register hermes.refresh 15m']);
        started.dispose();
      });

      test('registers when it starts already signed in', () async {
        connection.state = HermesConnectionState.ready;

        final started = scheduler(platform);
        await settle();

        expect(tasks.calls, ['initialize', 'register hermes.refresh 15m']);
        started.dispose();
      });

      test('asks once for a connection that stays ready', () async {
        final started = scheduler(platform);
        connection.moveTo(HermesConnectionState.ready);
        connection.notifyListeners();
        await settle();

        expect(
          tasks.calls.where((c) => c.startsWith('register')),
          hasLength(1),
        );
        started.dispose();
      });

      test(
        'cancels the run on sign-out and registers it again after',
        () async {
          final started = scheduler(platform);
          connection.moveTo(HermesConnectionState.ready);
          await settle();

          connection.ended.add(null);
          connection.moveTo(HermesConnectionState.needsLogin);
          await settle();
          connection.moveTo(HermesConnectionState.ready);
          await settle();

          expect(tasks.calls, [
            'initialize',
            'register hermes.refresh 15m',
            'cancel hermes.refresh',
            'register hermes.refresh 15m',
          ]);
          started.dispose();
        },
      );

      test('logs a refusal and does not throw', () async {
        tasks.registerFailure = Exception('refused');
        final started = scheduler(platform);

        connection.moveTo(HermesConnectionState.ready);
        await settle();

        expect(events.map((e) => e.$1), ['background.refresh.schedule_failed']);
        expect(events.single.$2, {
          'error.type': '_Exception',
          'platform': platform.name,
        });
        started.dispose();
      });

      test(
        'tries again after a refusal when the connection comes back',
        () async {
          tasks.registerFailure = Exception('refused');
          final started = scheduler(platform);
          connection.moveTo(HermesConnectionState.ready);
          await settle();

          tasks.registerFailure = null;
          connection.moveTo(HermesConnectionState.connectionError);
          connection.moveTo(HermesConnectionState.ready);
          await settle();

          expect(tasks.calls.last, 'register hermes.refresh 15m');
          started.dispose();
        },
      );
    });
  }

  group('keeping the run registered', () {
    test('registers it again on resume when the system lost it', () async {
      final started = scheduler(TargetPlatform.android);
      connection.moveTo(HermesConnectionState.ready);
      await settle();
      tasks.calls.clear();
      tasks.scheduled = false;

      started.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(tasks.calls, ['register hermes.refresh 15m']);
      started.dispose();
    });

    test('leaves it alone on resume while it is there', () async {
      final started = scheduler(TargetPlatform.android);
      connection.moveTo(HermesConnectionState.ready);
      await settle();
      tasks.calls.clear();

      started.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(tasks.calls, isEmpty);
      started.dispose();
    });

    test('leaves it alone on resume when the system cannot say', () async {
      final started = scheduler(TargetPlatform.iOS);
      connection.moveTo(HermesConnectionState.ready);
      await settle();
      tasks.calls.clear();
      tasks.scheduled = null;

      started.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(tasks.calls, isEmpty);
      started.dispose();
    });

    test('does nothing on resume while signed out', () async {
      final started = scheduler(TargetPlatform.android);
      connection.moveTo(HermesConnectionState.needsLogin);
      tasks.scheduled = false;

      started.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(tasks.calls, isEmpty);
      started.dispose();
    });

    test('a sign-out during the setup cancels, and nothing registers after '
        'it', () async {
      tasks.initializeGate = Completer<void>();
      final started = scheduler(TargetPlatform.android);
      connection.moveTo(HermesConnectionState.ready);
      await settle();

      connection.ended.add(null);
      connection.moveTo(HermesConnectionState.needsLogin);
      await settle();
      tasks.initializeGate!.complete();
      await settle();

      expect(tasks.calls, ['initialize', 'cancel hermes.refresh']);
      started.dispose();
    });
  });

  group('when the system will not run it', () {
    test('logs the status once per launch on iOS', () async {
      final status = _Status('denied');
      final started = scheduler(TargetPlatform.iOS, status: status);

      connection.moveTo(HermesConnectionState.ready);
      await settle();
      started.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(events.map((e) => e.$1), ['background.refresh.unavailable']);
      expect(events.single.$2, {'status': 'denied'});
      expect(status.reads, 1);
      started.dispose();
    });

    test('is silent while Background App Refresh is available', () async {
      final started = scheduler(
        TargetPlatform.iOS,
        status: _Status('available'),
      );

      connection.moveTo(HermesConnectionState.ready);
      await settle();

      expect(events, isEmpty);
      started.dispose();
    });

    test('has nothing to read on Android', () async {
      final started = scheduler(TargetPlatform.android, status: _Status(null));

      connection.moveTo(HermesConnectionState.ready);
      await settle();

      expect(events, isEmpty);
      started.dispose();
    });
  });

  group('telling the background runs the app is open', () {
    test('answers pings while in front and stops after', () async {
      final started = scheduler(
        TargetPlatform.android,
        presence: AppPresence(name: 'test-presence-open', resumed: () => true),
      );
      expect(await appInFront(name: 'test-presence-open'), isTrue);

      started.dispose();

      expect(await appInFront(name: 'test-presence-open'), isFalse);
    });

    test('an app that is alive but not resumed is not in front', () async {
      var resumed = false;
      final started = scheduler(
        TargetPlatform.android,
        presence: AppPresence(
          name: 'test-presence-paused',
          resumed: () => resumed,
        ),
      );

      expect(await appInFront(name: 'test-presence-paused'), isFalse);
      resumed = true;
      expect(await appInFront(name: 'test-presence-paused'), isTrue);

      started.dispose();
    });

    test('a port nobody answers on does not count', () async {
      final silent = ReceivePort();
      addTearDown(silent.close);
      IsolateNameServer.registerPortWithName(silent.sendPort, 'test-silent');
      addTearDown(() => IsolateNameServer.removePortNameMapping('test-silent'));

      expect(
        await appInFront(
          name: 'test-silent',
          timeout: const Duration(milliseconds: 100),
        ),
        isFalse,
      );
    });
  });

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('does nothing on $platform', () async {
      final started = scheduler(platform);

      connection.moveTo(HermesConnectionState.ready);
      connection.ended.add(null);
      await settle();

      expect(tasks.calls, isEmpty);
      started.dispose();
    });
  }
}
