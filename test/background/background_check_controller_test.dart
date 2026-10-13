import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/background_check_controller.dart';
import 'package:hermes_app/src/background/background_scheduler.dart';
import 'package:hermes_app/src/background/background_check_status.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Tasks implements PeriodicTasks {
  int queries = 0;
  int registrations = 0;
  @override
  Future<bool?> isScheduled(String name) async {
    queries++;
    return true;
  }

  @override
  Future<void> initialize(Function dispatcher) async {}
  @override
  Future<void> cancel(String name) async {}
  @override
  Future<void> register(String name, {required Duration interval}) async {
    registrations++;
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test(
    'resume reads capability without registering more periodic work',
    () async {
      final changes = ChangeNotifier();
      final ended = StreamController<void>.broadcast();
      final tasks = _Tasks();
      var permissions = 0;
      final controller = BackgroundCheckController(
        changes: changes,
        account: () => 'account-hash',
        signedOut: ended.stream,
        permission: () async {
          permissions++;
          return false;
        },
        tasks: tasks,
        name: () async => 'refresh',
        platform: TargetPlatform.android,
        observeLifecycle: false,
      );
      controller.start();
      await controller.refresh();
      final before = tasks.queries;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(tasks.queries, before + 1);
      expect(tasks.registrations, 0);
      expect(permissions, greaterThan(1));
      expect(controller.permission, false);
      expect(controller.capability, 'registered');
      controller.dispose();
      changes.dispose();
      await ended.close();
    },
  );
  test(
    'an account changed by a status listener owns subsequent bookkeeping',
    () async {
      final changes = ChangeNotifier();
      final ended = StreamController<void>.broadcast();
      final store = BackgroundCheckStore();
      var account = 'first';
      var switched = false;
      final controller = BackgroundCheckController(
        changes: changes,
        account: () => account,
        signedOut: ended.stream,
        permission: () async => true,
        store: store,
        tasks: _Tasks(),
        name: () async => 'refresh',
        platform: TargetPlatform.android,
        observeLifecycle: false,
      );
      addTearDown(() async {
        controller.dispose();
        changes.dispose();
        await ended.close();
      });
      controller.addListener(() {
        if (!switched) {
          switched = true;
          account = 'second';
          changes.notifyListeners();
        }
      });
      controller.start();
      await pumpEventQueue();
      expect((await store.begin())?.account, 'second');
    },
  );

  test('a new sign-in during sign-out notification survives cleanup', () async {
    final changes = ChangeNotifier();
    final ended = StreamController<void>.broadcast(sync: true);
    final store = BackgroundCheckStore();
    String? account = 'first';
    final controller = BackgroundCheckController(
      changes: changes,
      account: () => account,
      signedOut: ended.stream,
      permission: () async => true,
      store: store,
      tasks: _Tasks(),
      name: () async => 'refresh',
      platform: TargetPlatform.android,
      observeLifecycle: false,
    );
    addTearDown(() async {
      controller.dispose();
      changes.dispose();
      await ended.close();
    });
    controller.start();
    await pumpEventQueue();
    expect((await store.begin())?.account, 'first');
    var switched = false;
    controller.addListener(() {
      if (!switched) {
        switched = true;
        account = 'second';
        changes.notifyListeners();
      }
    });
    account = null;
    ended.add(null);
    await pumpEventQueue();
    expect((await store.begin())?.account, 'second');
  });
}
