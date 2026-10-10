import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/background/background_scheduler.dart';

class _Tasks implements PeriodicTasks {
  final calls = <String>[];
  Exception? registerFailure;

  @override
  Future<void> initialize(Function dispatcher) async => calls.add('initialize');

  @override
  Future<void> register(String name, {required Duration interval}) async {
    if (registerFailure case final error?) throw error;
    calls.add('register $name ${interval.inMinutes}m');
  }

  @override
  Future<void> cancel(String name) async => calls.add('cancel $name');
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

  BackgroundScheduler scheduler(TargetPlatform platform) => BackgroundScheduler(
    changes: connection,
    state: () => connection.state,
    ended: connection.ended.stream,
    tasks: tasks,
    platform: platform,
    name: () async => 'hermes.refresh',
    dispatcher: _dispatcher,
    events: (name, [attributes = const {}]) => events.add((name, attributes)),
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
