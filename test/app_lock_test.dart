import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_dialog.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/app_lock/device_authenticator.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:local_auth/local_auth.dart';
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

  AppLockController controller({bool coverWhenInactive = true}) {
    final lock = AppLockController(
      authenticator: authenticator,
      coverWhenInactive: coverWhenInactive,
    );
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
    test('tells an isolate without the controller whether it is on', () async {
      expect(await AppLockController.savedEnabled(), isFalse);

      await enabledLock();

      expect(await AppLockController.savedEnabled(), isTrue);
    });

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

    test('losing focus covers the app but does not lock it', () async {
      final lock = await enabledLock();
      authenticator.reasons.clear();

      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(lock.covered, isTrue);
      expect(lock.locked, isFalse);

      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(lock.covered, isFalse);
      expect(authenticator.reasons, isEmpty);
    });

    test('stays covered from losing focus until the device confirms', () async {
      final lock = await enabledLock();
      authenticator.succeeds = false;

      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);
      lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(lock.covered, isTrue);
      authenticator.succeeds = true;
      await lock.unlock();
      expect(lock.covered, isFalse);
    });

    test('the device prompt itself does not cover the app', () async {
      final lock = controller();
      await lock.load();
      authenticator.onAuthenticate = () =>
          lock.didChangeAppLifecycleState(AppLifecycleState.inactive);

      await lock.setEnabled(true);

      expect(lock.covered, isFalse);
    });

    test('losing focus does not cover where windows stay visible', () async {
      final lock = controller(coverWhenInactive: false);
      await lock.load();
      await lock.setEnabled(true);

      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(lock.covered, isFalse);
    });

    test('losing focus does not cover while the lock is off', () async {
      final lock = await relaunched();

      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(lock.covered, isFalse);
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

    test('stays locked at launch when the device cannot tell whether it '
        'can confirm, and unlocks once it confirms', () async {
      await enabledLock();
      authenticator
        ..available = null
        ..succeeds = false;

      final lock = await relaunched();

      expect(lock.locked, isTrue);
      expect(lock.covered, isTrue);
      expect(authenticator.reasons.last, 'Unlock Hermes');
      authenticator.succeeds = true;
      expect(await lock.unlock(), isTrue);
      expect(lock.locked, isFalse);
    });

    test('a device that could not tell is not offered the switch', () async {
      authenticator.available = null;
      final lock = await relaunched();

      expect(lock.available, isFalse);
      expect(await lock.setEnabled(true), isFalse);
      expect(authenticator.reasons, isEmpty);
    });

    test('a device that cannot tell and reports that it cannot confirm '
        'anyone does not lock the user out', () async {
      await enabledLock();
      authenticator
        ..available = null
        ..unavailable = true;

      final lock = await relaunched();

      expect(lock.locked, isFalse);
      expect(authenticator.reasons.last, 'Unlock Hermes');
    });

    test('a device that cannot confirm anyone but says it is supported '
        'stays locked', () async {
      await enabledLock();
      authenticator
        ..available = null
        ..unavailable = true;
      final lock = controller();
      final loading = lock.load();
      authenticator.available = true;
      await loading;

      expect(lock.locked, isTrue);
    });

    test('a device that could not tell is asked again by unlock, and one '
        'that now has no support is not locked', () async {
      await enabledLock();
      authenticator
        ..available = null
        ..succeeds = false;
      final lock = await relaunched();
      expect(lock.locked, isTrue);
      final prompts = authenticator.reasons.length;

      authenticator.available = false;
      expect(await lock.unlock(), isTrue);

      expect(lock.locked, isFalse);
      expect(authenticator.reasons, hasLength(prompts));
    });

    test('unlock reports whether the app is unlocked afterwards', () async {
      final lock = await relaunched();
      expect(await lock.unlock(), isTrue, reason: 'nothing to unlock');

      await lock.setEnabled(true);
      lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
      authenticator.succeeds = false;
      expect(await lock.unlock(), isFalse);
      expect(lock.locked, isTrue);

      authenticator.succeeds = true;
      expect(await lock.unlock(), isTrue);
      expect(lock.locked, isFalse);
    });

    test('unlock joins an attempt that is already in flight', () async {
      final lock = await enabledLock();
      lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
      authenticator.reasons.clear();
      final prompt = Completer<bool>();
      authenticator.answer = prompt.future;

      final first = lock.unlock();
      final second = lock.unlock();
      prompt.complete(true);

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(authenticator.reasons, ['Unlock Hermes']);
      expect(lock.locked, isFalse);
    });

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

    testWidgets('the covered app offers no menu bar commands', (tester) async {
      await tester.runAsync(enabledLock);
      authenticator.succeeds = false;
      final lock = (await tester.runAsync(relaunched))!;
      final registry = MacCommandRegistry();
      addTearDown(registry.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lock,
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            builder: (context, child) => MacCommandScope.root(
              registry: registry,
              child: AppLockGate(child: child!),
            ),
            home: MacCommandScope(
              commands: {MacCommand.copyTranscript: MacCommandHandler(() {})},
              child: const Text('chat'),
            ),
          ),
        ),
      );
      expect(registry.handlerFor(MacCommand.copyTranscript), isNull);

      authenticator.succeeds = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(registry.handlerFor(MacCommand.copyTranscript), isNotNull);
    });

    testWidgets('hides the app while it is inactive', (tester) async {
      final lock = (await tester.runAsync(enabledLock))!;
      await pumpGate(tester, lock);

      lock.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();

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
        tester.widget<GroupedSwitchRow>(find.byType(GroupedSwitchRow)).value;

    testWidgets('the switch turns the lock on', (tester) async {
      final lock = (await tester.runAsync(relaunched))!;
      await openDialog(tester, lock);
      expect(switchValue(tester), isFalse);

      await tester.tap(find.byType(Switch));
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
        tester
            .widget<GroupedSwitchRow>(find.byType(GroupedSwitchRow))
            .onChanged,
        isNull,
      );
      expect(find.textContaining('Set up a screen lock'), findsOneWidget);
    });

    for (final (platform, switchText, note) in [
      (TargetPlatform.iOS, 'Require Face ID or Touch ID', 'Set up Face ID'),
      (TargetPlatform.macOS, 'Require Face ID or Touch ID', 'Set up Face ID'),
      (
        TargetPlatform.android,
        'Require fingerprint or screen lock',
        'Set up a screen lock',
      ),
      (
        TargetPlatform.windows,
        'Require Windows Hello',
        'Set up Windows Hello or a PIN',
      ),
      (
        TargetPlatform.linux,
        'Require system unlock',
        'App Lock is not available on Linux',
      ),
    ]) {
      testWidgets('words itself for $platform', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        authenticator.available = false;
        final lock = (await tester.runAsync(relaunched))!;

        await openDialog(tester, lock);

        expect(find.text(switchText), findsOneWidget);
        expect(find.textContaining(note), findsOneWidget);
        if (platform == TargetPlatform.linux) {
          expect(find.textContaining('Face ID'), findsNothing);
          expect(find.textContaining('Windows Hello'), findsNothing);
        }
        debugDefaultTargetPlatformOverride = null;
      });
    }
  });

  group('LocalDeviceAuthenticator', () {
    test('cannot tell when the support check throws', () async {
      final device = LocalDeviceAuthenticator(auth: _FakeLocalAuth());

      expect(await device.isAvailable(), isNull);
    });

    test('reports what the support check answers', () async {
      expect(
        await LocalDeviceAuthenticator(auth: _FakeLocalAuth(supported: false))
            .isAvailable(),
        isFalse,
      );
    });

    test('is not supported where the platform has no implementation', () async {
      for (final error in [
        MissingPluginException('no local_auth on Linux'),
        UnimplementedError(),
      ]) {
        expect(
          await LocalDeviceAuthenticator(
            auth: _FakeLocalAuth(supportError: error),
          ).isAvailable(),
          isFalse,
          reason: '$error',
        );
      }
    });

    test(
      'tells a device that cannot confirm anyone from a failed confirm',
      () async {
        Future<DeviceAuthResult> result(Object answer) =>
            LocalDeviceAuthenticator(auth: _FakeLocalAuth(answer: answer))
                .authenticate('Unlock Hermes');

        expect(await result(true), DeviceAuthResult.confirmed);
        expect(await result(false), DeviceAuthResult.failed);
        expect(
          await result(
            const LocalAuthException(code: LocalAuthExceptionCode.userCanceled),
          ),
          DeviceAuthResult.failed,
        );
        expect(
          await result(
            const LocalAuthException(
              code: LocalAuthExceptionCode.temporaryLockout,
            ),
          ),
          DeviceAuthResult.failed,
        );
        expect(
          await result(
            const LocalAuthException(
              code: LocalAuthExceptionCode.noCredentialsSet,
            ),
          ),
          DeviceAuthResult.unavailable,
        );
        expect(
          await result(MissingPluginException()),
          DeviceAuthResult.unavailable,
        );
        expect(await result(StateError('boom')), DeviceAuthResult.failed);
      },
    );
  });
}

/// Answers the support check with [supported], or throws [supportError]
/// (a `StateError` when both are null); [authenticate] answers or throws
/// [answer].
class _FakeLocalAuth implements LocalAuthentication {
  _FakeLocalAuth({this.supported, this.supportError, this.answer = true});

  final bool? supported;
  final Object? supportError;
  final Object answer;

  @override
  Future<bool> isDeviceSupported() async {
    if (supportError case final error?) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    return supported ?? (throw StateError('no keyguard service'));
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    if (answer case final bool confirmed) return confirmed;
    Error.throwWithStackTrace(answer, StackTrace.current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
