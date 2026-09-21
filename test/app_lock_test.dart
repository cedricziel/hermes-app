import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_dialog.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_device_authenticator.dart';

void main() {
  late FakeDeviceAuthenticator authenticator;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    authenticator = FakeDeviceAuthenticator();
  });

  AppLockController controller() {
    final lock = AppLockController(authenticator: authenticator);
    addTearDown(lock.dispose);
    return lock;
  }

  Future<AppLockController> enabledLock() async {
    final lock = controller();
    await lock.load();
    await lock.setEnabled(true);
    return lock;
  }

  Future<AppLockController> relaunched() async {
    final lock = controller();
    await lock.load();
    return lock;
  }

  group('AppLockController', () {
    test('is off and unlocked on a fresh install', () async {
      final lock = await relaunched();

      expect(lock.loaded, isTrue);
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
      expect(authenticator.reasons, isEmpty);
    });

    test('turning it on asks the device first and stays unlocked', () async {
      final lock = await relaunched();

      expect(await lock.setEnabled(true), isTrue);

      expect(authenticator.reasons, ['Confirm to turn on app lock']);
      expect(lock.enabled, isTrue);
      expect(lock.locked, isFalse);
    });

    test('stays off when the device does not confirm', () async {
      final lock = await relaunched();
      authenticator.succeeds = false;

      expect(await lock.setEnabled(true), isFalse);

      expect(lock.enabled, isFalse);
      expect((await relaunched()).enabled, isFalse);
    });

    test('cannot be turned on without device support', () async {
      authenticator.available = false;
      final lock = await relaunched();

      expect(lock.available, isFalse);
      expect(await lock.setEnabled(true), isFalse);
      expect(lock.enabled, isFalse);
      expect(authenticator.reasons, isEmpty);
    });

    test('locks at launch and unlocks when the device confirms', () async {
      await enabledLock();

      final lock = await relaunched();

      expect(lock.enabled, isTrue);
      expect(lock.locked, isFalse);
      expect(authenticator.reasons.last, 'Unlock Hermes');
    });

    test('stays locked at launch when the device does not confirm', () async {
      await enabledLock();
      authenticator.succeeds = false;

      final lock = await relaunched();

      expect(lock.locked, isTrue);
      authenticator.succeeds = true;
      await lock.unlock();
      expect(lock.locked, isFalse);
    });

    test(
      'locks when the app leaves the screen and unlocks on return',
      () async {
        final lock = await enabledLock();
        authenticator.reasons.clear();

        lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
        expect(lock.locked, isTrue);

        lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(lock.locked, isFalse);
        expect(authenticator.reasons, ['Unlock Hermes']);
      },
    );

    test('losing focus alone does not lock', () async {
      final lock = await enabledLock();

      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(lock.locked, isFalse);
    });

    test('never locks while it is off', () async {
      final lock = await relaunched();

      lock.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(lock.locked, isFalse);
    });

    test(
      'a saved "on" is not enforced once the device cannot confirm',
      () async {
        await enabledLock();
        authenticator.available = false;

        final lock = await relaunched();

        expect(lock.locked, isFalse);
      },
    );

    test('turning it off is remembered', () async {
      final lock = await enabledLock();

      await lock.setEnabled(false);

      expect((await relaunched()).enabled, isFalse);
    });
  });

  group('AppLockGate', () {
    Future<void> pumpGate(WidgetTester tester, AppLockController lock) {
      return tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lock,
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            builder: (context, child) => AppLockGate(child: child!),
            home: const Text('chat'),
          ),
        ),
      );
    }

    testWidgets('hides the app and offers unlock while locked', (tester) async {
      await tester.runAsync(enabledLock);
      authenticator.succeeds = false;
      final lock = (await tester.runAsync(relaunched))!;

      await pumpGate(tester, lock);

      expect(find.text('chat'), findsNothing);
      expect(find.text('Hermes is locked'), findsOneWidget);

      authenticator.succeeds = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('chat'), findsOneWidget);
      expect(find.text('Hermes is locked'), findsNothing);
    });

    testWidgets('covers the app until the saved choice has loaded', (
      tester,
    ) async {
      await pumpGate(tester, controller());

      expect(find.text('chat'), findsNothing);
      expect(find.text('Unlock'), findsNothing);
    });

    testWidgets('shows the app when the lock is off', (tester) async {
      final lock = (await tester.runAsync(relaunched))!;

      await pumpGate(tester, lock);

      expect(find.text('chat'), findsOneWidget);
    });
  });

  group('App lock dialog', () {
    Future<void> openDialog(WidgetTester tester, AppLockController lock) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lock,
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppLockDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    bool? switchValue(WidgetTester tester) =>
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

    testWidgets('the switch turns the lock on', (tester) async {
      final lock = (await tester.runAsync(relaunched))!;
      await openDialog(tester, lock);
      expect(switchValue(tester), isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(lock.enabled, isTrue);
      expect(switchValue(tester), isTrue);
    });

    testWidgets('explains and disables the switch without device support', (
      tester,
    ) async {
      authenticator.available = false;
      final lock = (await tester.runAsync(relaunched))!;

      await openDialog(tester, lock);

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(find.textContaining('Set up Face ID'), findsOneWidget);
    });
  });
}
