import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/tools/toolset_installs.dart';
import 'package:hermes_app/src/tools/tools_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import 'tools_screen_fixtures.dart' show writeBody;
import 'tools_setup_harness.dart';
import 'tools_setup_world.dart';

/// What runs on the server: the install step, the Local backend and the
/// permission grant. Nothing is sent before the user answers the question;
/// Cancel is the default and sends nothing.
void main() {
  late SetupWorld world;
  late SetupHarness h;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  const postSetup = '/api/tools/toolsets/computer_use/post-setup';
  const grant = '/api/tools/computer-use/permissions/grant';
  const backend = '/api/tools/terminal/backend';

  Future<void> start(
    WidgetTester tester, {
    void Function(SetupWorld world)? prepare,
    ToolsetInstalls? installs,
    ToolsBotScreenLink? botScreen,
    Size size = phone,
    TargetPlatform platform = TargetPlatform.android,
    AppLockController? lock,
  }) async {
    world = SetupWorld();
    prepare?.call(world);
    h = SetupHarness(tester, world);
    await h.pump(
      installs: installs,
      botScreen: botScreen,
      size: size,
      platform: platform,
      lock: lock,
    );
  }

  void background(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void foreground(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Future<AppLockController> newLock(WidgetTester tester) async {
    late AppLockController lock;
    await tester.runAsync(() async {
      lock = AppLockController(
        authenticator: FakeDeviceAuthenticator(),
        coverWhenInactive: true,
      );
      await lock.load();
      await lock.setEnabled(true);
    });
    addTearDown(lock.dispose);
    return lock;
  }

  group('the install step', () {
    Future<void> openInstall(WidgetTester tester) async {
      await h.openComputerUse();
    }

    testWidgets('the filled button asks first and sends nothing before an '
        'answer; Cancel sends nothing', (tester) async {
      await start(tester);
      await openInstall(tester);

      expect(find.text('Install on server'), findsOneWidget);
      expect(
        find.text('Needed before this works. The app asks first.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();

      expect(find.text('Install on your server?'), findsOneWidget);
      expect(
        find.text(
          'Hermes will run an installer on the server. It may download software.',
        ),
        findsOneWidget,
      );
      expect(world.server.requestsTo('POST', postSetup), isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(world.server.requestsTo('POST', postSetup), isEmpty);
      expect(find.text('Installing on your server…'), findsNothing);
      await h.close();
    });

    testWidgets('after Install it sends the step with the profile and '
        'follows the log', (tester) async {
      await start(tester);
      await openInstall(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Install').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final bodies = world.bodies('POST', postSetup);
      expect(bodies, hasLength(1));
      expect(bodies.single['key'], 'cua_driver');
      expect(bodies.single['profile'], 'work');
      expect(find.text('Installing on your server…'), findsOneWidget);
      expect(
        find.text('You can leave this screen. The install keeps going.'),
        findsOneWidget,
      );
      expect(find.text('Downloading the driver'), findsOneWidget);
      // The button is gone while it runs.
      expect(
        find.widgetWithText(FilledButton, 'Install on server'),
        findsNothing,
      );

      await h.close();
    });

    testWidgets('an install that ends with 0 says Checking, reads the setup '
        'again and then says Installed', (tester) async {
      await start(tester);
      await openInstall(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install').last);
      await tester.pump(const Duration(milliseconds: 100));
      final reads = world.server
          .requestsTo('GET', '/api/tools/toolsets/computer_use/config')
          .length;

      world
        ..installRunning = false
        ..installExit = 0
        ..driverInstalled = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Installed.'), findsOneWidget);
      expect(
        world.server
            .requestsTo('GET', '/api/tools/toolsets/computer_use/config')
            .length,
        greaterThan(reads),
      );
      // The readiness is read again: the driver is installed now.
      expect(find.text('Installed'), findsOneWidget);
      await h.close();
    });

    testWidgets('a failed install says so with the lines and Try again, '
        'which asks again', (tester) async {
      await start(tester);
      await openInstall(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install').last);
      await tester.pump(const Duration(milliseconds: 100));

      world
        ..installRunning = false
        ..installExit = 1
        ..installLines = ['Downloading the driver', 'No space left'];
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text("The install didn't finish."), findsOneWidget);
      expect(find.text('No space left'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Install on your server?'), findsOneWidget);
      expect(world.server.requestsTo('POST', postSetup), hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(world.server.requestsTo('POST', postSetup), hasLength(1));
      await h.close();
    });

    testWidgets('an end with no exit code is unknown, not Installed', (
      tester,
    ) async {
      await start(tester);
      await openInstall(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install').last);
      await tester.pump(const Duration(milliseconds: 100));

      world
        ..installRunning = false
        ..installExit = null;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't tell whether it finished."), findsOneWidget);
      expect(find.text('Installed.'), findsNothing);
      await h.close();
    });

    testWidgets('a refused start shows Hermes\' sentence and follows nothing', (
      tester,
    ) async {
      await start(tester);
      await openInstall(tester);
      world.server.on('POST', postSetup, {
        'detail': 'Unknown post-setup key.',
      }, status: 400);
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Install').last);
      await tester.pumpAndSettle();

      expect(find.text('Unknown post-setup key.'), findsOneWidget);
      expect(
        world.server.requestsTo('GET', '/api/actions/tools-post-setup/status'),
        isEmpty,
      );
      await h.close();
    });

    testWidgets('a follow that keeps failing offers Check again', (
      tester,
    ) async {
      await start(tester);
      await openInstall(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      world.server.on('GET', '/api/actions/tools-post-setup/status', {
        'detail': 'x',
      }, status: 500);
      await tester.tap(find.text('Install').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Couldn\'t follow the install. Trying again…'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't follow the install. Check again."),
        findsOneWidget,
      );
      expect(find.text('Check again'), findsOneWidget);
      await h.close();
    });

    testWidgets('another install disables the button and says so', (
      tester,
    ) async {
      late ToolsetInstalls installs;
      installs = ToolsetInstalls(requestReread: (_) {});
      addTearDown(installs.dispose);
      await start(tester, installs: installs);
      await openInstall(tester);

      installs.followSwitchStarted(h.repository, 'other', toolset: 'web');
      await tester.pump(const Duration(milliseconds: 100));

      final button = find.widgetWithText(
        FilledButton,
        'Another install is running',
      );
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Install on your server?'), findsNothing);
      expect(world.server.requestsTo('POST', postSetup), isEmpty);
      installs.clear();
      await h.close();
    });

    testWidgets('the progress survives leaving the screen', (tester) async {
      late ToolsetInstalls installs;
      installs = ToolsetInstalls(requestReread: (_) {});
      addTearDown(installs.dispose);
      await start(tester, installs: installs);
      await openInstall(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Installing on your server…'), findsOneWidget);

      await h.close();
      await h.pump(installs: installs);
      await h.openComputerUse(settle: false);

      expect(find.text('Installing on your server…'), findsOneWidget);
      expect(find.text('Downloading the driver'), findsOneWidget);
      // Still one start, not a second.
      expect(world.server.requestsTo('POST', postSetup), hasLength(1));
      installs.clear();
      await h.close();
    });

    testWidgets('an install the switch started is followed, and Show opens '
        'its section', (tester) async {
      await start(tester);
      world.server.onRequest('PUT', '/api/tools/toolsets/computer_use', (r) {
        world.enabled.add('computer_use');
        return (
          status: 200,
          body: {
            'ok': true,
            'name': 'computer_use',
            'enabled': true,
            'post_setup_started': 'cua_driver',
          },
        );
      });

      final sw = find.descendant(
        of: find.byKey(const ValueKey('tool-row-computer_use')),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(sw);
      await tester.pump();
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(find.text('Let Hermes control a computer?'), findsOneWidget);
      await tester.tap(find.text('Switch on'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Computer use is on.'), findsOneWidget);
      // Followed from the answer on, with nothing sent but the switch.
      expect(
        world.server.requestsTo('GET', '/api/actions/tools-post-setup/status'),
        isNotEmpty,
      );
      expect(world.server.requestsTo('POST', postSetup), isEmpty);

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Hermes is installing the driver on your server.'),
        findsOneWidget,
      );
      await h.close();
    });

    testWidgets('a provider that is ready offers the step again under '
        'Advanced, and only after a question', (tester) async {
      await start(
        tester,
        prepare: (w) {
          w.webActive = 'Local Driver';
          w.webInstalled = true;
        },
      );
      await h.openWeb();
      await h.tapText('Change setup');

      expect(
        find.widgetWithText(FilledButton, 'Install on server'),
        findsNothing,
      );
      expect(find.text('Run the install step again'), findsNothing);
      await h.tapText('Use different providers for search and extract');
      expect(find.text('Run the install step again'), findsOneWidget);
      await tester.tap(find.text('Run the install step again'));
      await tester.pumpAndSettle();
      expect(find.text('Install on your server?'), findsOneWidget);
      expect(
        world.server.requestsTo('POST', '/api/tools/toolsets/web/post-setup'),
        isEmpty,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await h.close();
    });
  });

  group('where commands run', () {
    testWidgets('lists the backends with Hermes\' text for one that is not '
        'ready', (tester) async {
      await start(tester);
      await h.openTerminal();

      expect(find.text('Where commands run'), findsOneWidget);
      expect(h.provider('local'), findsOneWidget);
      expect(h.provider('docker'), findsOneWidget);
      expect(find.text('From Hermes: Docker CLI not found.'), findsOneWidget);
      expect(find.text('Needs setup'), findsOneWidget);
      expect(
        world.server
            .requestsTo('GET', '/api/tools/terminal/backends')
            .single
            .queryParameters['profile'],
        'work',
      );
      await h.close();
    });

    testWidgets('a backend that needs setup can be picked and warns', (
      tester,
    ) async {
      await start(tester);
      await h.openTerminal();

      await h.pick('docker');

      final bodies = world.bodies('PUT', backend);
      expect(bodies.single['backend'], 'docker');
      expect(bodies.single['profile'], 'work');
      expect(
        find.text('Commands will fail until this is set up on your server.'),
        findsOneWidget,
      );
      await h.close();
    });

    testWidgets('Local asks first and sends nothing until confirmed', (
      tester,
    ) async {
      await start(tester, prepare: (w) => w.backend = 'docker');
      await h.openTerminal();

      await tester.ensureVisible(h.provider('local'));
      await tester.pump();
      await tester.tap(h.provider('local'));
      await tester.pumpAndSettle();

      expect(
        find.text('Run commands directly on your server?'),
        findsOneWidget,
      );
      expect(world.server.requestsTo('PUT', backend), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(world.server.requestsTo('PUT', backend), isEmpty);
      expect(world.backend, 'docker');

      await tester.tap(h.provider('local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use local'));
      await tester.pumpAndSettle();
      expect(world.bodies('PUT', backend).single['backend'], 'local');
      await h.close();
    });

    testWidgets('a refused pick shows Hermes\' sentence', (tester) async {
      await start(tester);
      await h.openTerminal();
      world.server.on('PUT', backend, {
        'detail': 'Unknown backend.',
      }, status: 400);

      await h.pick('docker');

      expect(find.text('Unknown backend.'), findsOneWidget);
      expect(world.backend, 'local');
      await h.close();
    });

    testWidgets('is not there when the route answers 404, and the rest of '
        'the details work', (tester) async {
      await start(tester);
      world.server.on('GET', '/api/tools/terminal/backends', {
        'detail': 'Not Found',
      }, status: 404);
      await h.openTerminal();

      expect(find.text('Where commands run'), findsNothing);
      expect(find.text('Where it applies'), findsOneWidget);
      await h.close();
    });

    testWidgets('loading and a failed read with Try again', (tester) async {
      await start(tester);
      world.server.on('GET', '/api/tools/terminal/backends', {
        'detail': 'x',
      }, status: 500);
      await h.openTerminal();

      expect(find.text("Couldn't read where commands run."), findsOneWidget);
      world.server.onRequest(
        'GET',
        '/api/tools/terminal/backends',
        (_) => (status: 200, body: world.backends()),
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(h.provider('docker'), findsOneWidget);
      await h.close();
    });
  });

  group('Computer use', () {
    void mac(SetupWorld w) => w
      ..driverInstalled = true
      ..screenRecording = false;

    testWidgets('a Mac server missing screen recording shows the rows and '
        'Allow access', (tester) async {
      await start(tester, prepare: mac);
      await h.openComputerUse();

      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('macOS, supported'), findsOneWidget);
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('Screen recording'), findsOneWidget);
      expect(find.text('Not allowed'), findsOneWidget);
      expect(find.text('Allow access'), findsOneWidget);
      await h.close();
    });

    testWidgets('Allow access asks first, sends nothing before the answer '
        'and nothing on Cancel', (tester) async {
      await start(tester, prepare: mac);
      await h.openComputerUse();

      await tester.tap(find.widgetWithText(FilledButton, 'Allow access'));
      await tester.pumpAndSettle();

      expect(find.text("Allow access on the server's Mac?"), findsOneWidget);
      expect(world.server.requestsTo('POST', grant), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(world.server.requestsTo('POST', grant), isEmpty);
      expect(find.widgetWithText(FilledButton, 'Allow access'), findsOneWidget);
      await h.close();
    });

    testWidgets('after the question it sends the grant, follows it and '
        'reads the status again at the end', (tester) async {
      await start(tester, prepare: mac);
      await h.openComputerUse();
      await tester.tap(find.widgetWithText(FilledButton, 'Allow access'));
      await tester.pumpAndSettle();
      final reads = world.server
          .requestsTo('GET', '/api/tools/computer-use/status')
          .length;

      await tester.tap(find.text('Allow access').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(world.server.requestsTo('POST', grant), hasLength(1));
      expect(
        find.text('Waiting for approval on the Mac that runs Hermes…'),
        findsOneWidget,
      );

      world
        ..grantRunning = false
        ..grantExit = 0
        ..screenRecording = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(
        world.server.requestsTo('GET', '/api/tools/computer-use/status').length,
        greaterThan(reads),
      );
      expect(find.text('Not allowed'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Allow access'), findsNothing);
      await h.close();
    });

    testWidgets('a refused grant shows Hermes\' sentence and follows nothing', (
      tester,
    ) async {
      await start(tester, prepare: mac);
      await h.openComputerUse();
      world.server.on('POST', grant, {
        'detail': 'Computer Use permission grants are a macOS concept.',
      }, status: 400);
      await tester.tap(find.widgetWithText(FilledButton, 'Allow access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow access').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Computer Use permission grants are a macOS concept.'),
        findsOneWidget,
      );
      expect(
        world.server.requestsTo(
          'GET',
          '/api/actions/computer-use-grant/status',
        ),
        isEmpty,
      );
      await h.close();
    });

    testWidgets('a Linux server shows only the driver and ready rows', (
      tester,
    ) async {
      await start(
        tester,
        prepare: (w) => w
          ..platform = 'linux'
          ..driverInstalled = true,
      );
      await h.openComputerUse();

      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Accessibility'), findsNothing);
      expect(find.text('Screen recording'), findsNothing);
      expect(find.text('Allow access'), findsNothing);
      await h.close();
    });

    testWidgets('the Mac without the driver offers the install, not Allow '
        'access', (tester) async {
      await start(tester);
      await h.openComputerUse();

      expect(find.text('Not installed'), findsOneWidget);
      expect(find.text('Allow access'), findsNothing);
      expect(find.text('Install on server'), findsOneWidget);
      await h.close();
    });

    testWidgets('the section is not there on an old server', (tester) async {
      await start(tester);
      world.server.on('GET', '/api/tools/computer-use/status', {
        'detail': 'Not Found',
      }, status: 404);
      await h.openComputerUse();

      expect(find.text('Readiness'), findsNothing);
      expect(find.text('Where it applies'), findsOneWidget);
      await h.close();
    });

    testWidgets('a failed read says it could not be read, with Try again', (
      tester,
    ) async {
      await start(tester);
      world.server.on('GET', '/api/tools/computer-use/status', {
        'detail': 'x',
      }, status: 500);
      await h.openComputerUse();

      expect(find.text("Couldn't read this."), findsOneWidget);
      expect(find.text('Where it applies'), findsOneWidget);
      await h.close();
    });
  });

  group("Open the bot's screen", () {
    testWidgets('is absent where the caller has no Bot Screen', (tester) async {
      await start(tester, prepare: (w) => w.driverInstalled = true);
      await h.openComputerUse();

      expect(find.text("Open the bot's screen"), findsNothing);
      await h.close();
    });

    testWidgets('is absent when the profile has none', (tester) async {
      final changes = ValueNotifier(0);
      addTearDown(changes.dispose);
      await start(
        tester,
        prepare: (w) => w.driverInstalled = true,
        botScreen: ToolsBotScreenLink(
          changes: changes,
          offered: () => false,
          open: () {},
        ),
      );
      await h.openComputerUse();

      expect(find.text("Open the bot's screen"), findsNothing);
      await h.close();
    });

    testWidgets('shows when the Bot Screen is offered and opens the viewer, '
        'and follows a change', (tester) async {
      final changes = ValueNotifier(0);
      addTearDown(changes.dispose);
      var offered = false;
      var opened = 0;
      await start(
        tester,
        prepare: (w) => w.driverInstalled = true,
        botScreen: ToolsBotScreenLink(
          changes: changes,
          offered: () => offered,
          open: () => opened++,
        ),
      );
      await h.openComputerUse();
      expect(find.text("Open the bot's screen"), findsNothing);

      offered = true;
      changes.value++;
      await tester.pump();
      expect(find.text("Open the bot's screen"), findsOneWidget);
      await tester.tap(find.text("Open the bot's screen"));
      expect(opened, 1);
      await h.close();
    });

    testWidgets('is only in the Computer use details', (tester) async {
      final changes = ValueNotifier(0);
      addTearDown(changes.dispose);
      await start(
        tester,
        botScreen: ToolsBotScreenLink(
          changes: changes,
          offered: () => true,
          open: () {},
        ),
      );
      await h.openTerminal();

      expect(find.text("Open the bot's screen"), findsNothing);
      await h.close();
    });
  });

  group('App Lock', () {
    testWidgets('locking clears a typed key and the field is empty after '
        'unlocking', (tester) async {
      final lock = await newLock(tester);
      await start(tester, lock: lock);
      await h.openWeb();
      await h.type(typedKey);
      expect(h.fieldText, typedKey);

      background(tester);
      await tester.pump();
      expect(lock.locked, isTrue);
      expect(h.fieldText, isEmpty);

      foreground(tester);
      await tester.pumpAndSettle();
      expect(h.fieldText, isEmpty);
      expect(find.text('0 characters entered'), findsNothing);
      // Save has nothing to send.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      await h.close();
    });

    testWidgets('going inactive hides a shown key and keeps the typed text', (
      tester,
    ) async {
      final lock = await newLock(tester);
      await start(tester, lock: lock);
      await h.openWeb();
      await h.type(typedKey);
      await h.showKey();
      expect(h.fieldObscured, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(h.fieldObscured, isTrue);
      expect(h.fieldText, typedKey);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.fieldText, typedKey);
      expect(h.fieldObscured, isTrue);
      await h.close();
    });

    testWidgets('locking takes an open install question down, sending '
        'nothing', (tester) async {
      final lock = await newLock(tester);
      await start(tester, lock: lock);
      await h.openComputerUse();
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      expect(find.text('Install on your server?'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      expect(find.text('Install on your server?'), findsNothing);
      expect(world.server.requestsTo('POST', postSetup), isEmpty);
      await h.close();
    });
  });

  group('closing', () {
    testWidgets('leaving the details drops what was typed', (tester) async {
      await start(tester);
      await h.openWeb();
      await h.type(typedKey);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await h.openWeb();

      expect(h.fieldText, isEmpty);
      await h.close();
    });

    testWidgets('moving to another toolset in the pane drops what was '
        'typed', (tester) async {
      await start(tester, size: wide);
      await tester.pumpAndSettle();
      await h.type(typedKey);
      expect(h.fieldText, typedKey);

      final todo = find.descendant(
        of: find.byKey(const Key('tools-list')),
        matching: find.text('Keep a to-do list while working.'),
      );
      await tester.ensureVisible(todo);
      await tester.pump();
      await tester.tap(todo);
      await tester.pumpAndSettle();
      final web = find.descendant(
        of: find.byKey(const Key('tools-list')),
        matching: find.text('Look things up on the web and read pages.'),
      );
      await tester.tap(web);
      await tester.pumpAndSettle();

      expect(h.fieldText, isEmpty);
      await h.close();
    });
  });

  test('the typed value is a constant of the tests, never a real key', () {
    expect(typedKey, startsWith('sk-test-'));
    expect(writeBody, isNotNull);
  });
}
