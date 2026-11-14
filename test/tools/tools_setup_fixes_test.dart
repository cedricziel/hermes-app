import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/tools/tools_asker.dart';
import 'package:hermes_app/src/tools/toolset_copy.dart';
import 'package:hermes_app/src/tools/toolset_installs.dart';
import 'package:hermes_app/src/tools/widgets/toolset_header.dart';
import 'package:hermes_app/src/tools/widgets/tools_switch.dart';
import 'package:hermes_app/l10n/l10n.dart';

import '../support/protected_catalog_auth.dart';
import 'tools_setup_harness.dart';
import 'tools_setup_world.dart';

class _Auth extends ProtectedCatalogAuth {
  _Auth(super.server);

  var signedIn = true;

  @override
  HermesConnectionState get state =>
      signedIn ? HermesConnectionState.ready : HermesConnectionState.needsLogin;

  void change() => notifyListeners();
}

/// One write at a time in both directions, one install button, and what a
/// question and a typed key do when the profile or the account goes.
void main() {
  late SetupWorld world;
  late SetupHarness h;

  const web = '/api/tools/toolsets/web';
  const postSetup = '/api/tools/toolsets/computer_use/post-setup';

  Future<void> start(
    WidgetTester tester, {
    Size size = phone,
    void Function(SetupWorld)? prepare,
    ToolsetInstalls? installs,
    AuthController Function(SetupWorld)? auth,
    ValueNotifier<String>? profile,
  }) async {
    world = SetupWorld();
    prepare?.call(world);
    h = SetupHarness(tester, world);
    await h.pump(
      size: size,
      installs: installs,
      auth: auth?.call(world),
      profile: profile,
    );
  }

  Finder headerSwitch() => find.descendant(
    of: find.byType(ToolsetHeader),
    matching: find.byType(ToolsSwitch),
  );

  Future<void> startInstall(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install').last);
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('one install button', () {
    testWidgets('a failed install has the block\'s Try again and nothing '
        'else filled', (tester) async {
      await start(tester);
      await h.openComputerUse();
      await startInstall(tester);

      world
        ..installRunning = false
        ..installExit = 1;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text("The install didn't finish."), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Install on server'),
        findsNothing,
      );
      await h.close();
    });

    testWidgets('after a success it says Checking with no install button', (
      tester,
    ) async {
      await start(tester);
      await h.openComputerUse();
      await startInstall(tester);
      final gate = Completer<void>();
      world.server.onRequest('GET', '/api/tools/toolsets/computer_use/config', (
        _,
      ) async {
        await gate.future;
        return (status: 200, body: world.computerConfig());
      });

      world
        ..installRunning = false
        ..installExit = 0;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Checking…'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      await h.close();
    });

    testWidgets('an unknown end has no second button beside it', (
      tester,
    ) async {
      await start(tester);
      await h.openComputerUse();
      await startInstall(tester);

      world
        ..installRunning = false
        ..installExit = null;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't tell whether it finished."), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await h.close();
    });
  });

  group('a switch and a setup write do not overlap', () {
    testWidgets('while the switch is saving a provider tap, a Save and a '
        'model pick send nothing', (tester) async {
      await start(tester, size: wide);
      final gate = Completer<void>();
      world.server.onRequest('PUT', web, (_) async {
        await gate.future;
        return (
          status: 200,
          body: {'ok': true, 'name': 'web', 'enabled': false},
        );
      });
      await h.type(typedKey);

      final rowSwitch = find.descendant(
        of: find.byKey(const ValueKey('tool-row-web')),
        matching: find.byType(ToolsSwitch),
      );
      await tester.tap(rowSwitch);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ToolsSwitch>(rowSwitch).saving, isTrue);

      final before = world.server.requests.length;
      await tester.tap(h.provider('Local Driver'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(save, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        world.server.requests.skip(before).where((r) => r.method != 'GET'),
        isEmpty,
      );
      expect(world.server.requestsTo('PUT', '$web/provider'), isEmpty);
      expect(world.server.requestsTo('PUT', '$web/env'), isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      await h.close();
    });

    testWidgets('a backend pick locks the switch and reads the list again', (
      tester,
    ) async {
      await start(tester, size: wide);
      await h.openTerminal();
      final gate = Completer<void>();
      world.server.onRequest('PUT', '/api/tools/terminal/backend', (r) async {
        await gate.future;
        world.backend = 'docker';
        return (status: 200, body: {'ok': true, 'backend': 'docker'});
      });
      final reads = world.server
          .requestsTo('GET', '/api/tools/toolsets')
          .length;

      await tester.ensureVisible(h.provider('docker'));
      await tester.tap(h.provider('docker'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ToolsSwitch>(headerSwitch()).onChanged, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ToolsSwitch>(headerSwitch()).onChanged, isNotNull);
      expect(
        world.server.requestsTo('GET', '/api/tools/toolsets').length,
        greaterThan(reads),
      );
      await h.close();
    });

    testWidgets('the grant locks the switch while the window is out', (
      tester,
    ) async {
      await start(
        tester,
        size: wide,
        prepare: (w) => w
          ..driverInstalled = true
          ..screenRecording = false,
      );
      await h.openComputerUse();
      await tester.tap(find.widgetWithText(FilledButton, 'Allow access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow access').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<ToolsSwitch>(headerSwitch()).onChanged, isNull);

      world
        ..grantRunning = false
        ..grantExit = 0;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(tester.widget<ToolsSwitch>(headerSwitch()).onChanged, isNotNull);
      await h.close();
    });
  });

  group('a question and a typed key when the profile or account goes', () {
    testWidgets('a profile change takes an open install question down and '
        'sends nothing', (tester) async {
      final profile = ValueNotifier('work');
      addTearDown(profile.dispose);
      await start(tester, profile: profile);
      await h.openComputerUse();
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      expect(find.text('Install on your server?'), findsOneWidget);

      profile.value = 'home';
      await tester.pumpAndSettle();

      expect(find.text('Install on your server?'), findsNothing);
      expect(world.server.requestsTo('POST', postSetup), isEmpty);
      await h.close();
    });

    testWidgets('a profile change drops a typed key', (tester) async {
      final profile = ValueNotifier('work');
      addTearDown(profile.dispose);
      await start(tester, profile: profile);
      await h.openWeb();
      await h.type(typedKey);

      profile.value = 'home';
      await tester.pumpAndSettle();
      await h.openWeb();

      expect(h.fieldText, isEmpty);
      expect(world.server.requestsTo('PUT', '$web/env'), isEmpty);
      await h.close();
    });

    testWidgets('signing out with the screen open drops a typed key', (
      tester,
    ) async {
      late _Auth auth;
      await start(tester, auth: (w) => auth = _Auth(w.server));
      addTearDown(auth.dispose);
      await h.openWeb();
      await h.type(typedKey);
      expect(h.fieldText, typedKey);

      auth.signedIn = false;
      auth.change();
      await tester.pump();

      expect(h.fieldText, isEmpty);
      await h.close();
    });

    testWidgets('clearing the connection\'s installs stops following a '
        'running install', (tester) async {
      final installs = ToolsetInstalls(requestReread: (_) {});
      addTearDown(installs.dispose);
      await start(tester, installs: installs);
      await h.openComputerUse();
      await startInstall(tester);
      expect(find.text('Installing on your server…'), findsOneWidget);
      final reads = world.server
          .requestsTo('GET', '/api/actions/tools-post-setup/status')
          .length;

      installs.clear();
      await tester.pump(const Duration(seconds: 10));

      expect(
        world.server
            .requestsTo('GET', '/api/actions/tools-post-setup/status')
            .length,
        reads,
      );
      expect(find.text('Installing on your server…'), findsNothing);
      expect(installs.state, isNull);
      await h.close();
    });
  });

  group('a write belongs to its controller, not to the panel', () {
    testWidgets('opening another toolset mid-save keeps the old switch '
        'locked until the write settles, and the result waits', (tester) async {
      await start(tester, size: wide);
      final gate = Completer<void>();
      world.server.onRequest('PUT', '$web/env', (request) async {
        await gate.future;
        world.webKeySet = true;
        return (
          status: 200,
          body: {
            'ok': true,
            'name': 'web',
            'saved': ['SEARCHCO_API_KEY'],
            'skipped': <Object?>[],
          },
        );
      });
      await h.type(typedKey);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));

      // Another toolset opens; the Web panel is gone.
      final todo = find.descendant(
        of: find.byKey(const Key('tools-list')),
        matching: find.text('Keep a to-do list while working.'),
      );
      await tester.ensureVisible(todo);
      await tester.tap(todo);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNothing);

      final rowSwitch = find.descendant(
        of: find.byKey(const ValueKey('tool-row-web')),
        matching: find.byType(ToolsSwitch),
      );
      expect(tester.widget<ToolsSwitch>(rowSwitch).onChanged, isNull);
      await tester.tap(rowSwitch, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(world.server.requestsTo('PUT', web), isEmpty);
      expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ToolsSwitch>(rowSwitch).onChanged, isNotNull);

      // Back on Web: the save's result is there.
      final webRow = find.descendant(
        of: find.byKey(const Key('tools-list')),
        matching: find.text('Look things up on the web and read pages.'),
      );
      await tester.tap(webRow);
      await tester.pumpAndSettle();
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Already set'), findsOneWidget);
      await h.close();
    });
  });

  group('installs wait for every write', () {
    testWidgets('no install question during a provider pick', (tester) async {
      await start(tester, prepare: (w) => w.webActive = 'Local Driver');
      await h.openWeb();
      final gate = Completer<void>();
      world.server.onRequest('PUT', '$web/provider', (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'name': 'web'});
      });
      await tester.ensureVisible(h.provider('Search Co'));
      await tester.tap(h.provider('Search Co'));
      await tester.pump(const Duration(milliseconds: 100));

      final install = find.widgetWithText(FilledButton, 'Install on server');
      expect(tester.widget<FilledButton>(install).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(world.server.requestsTo('POST', '$web/post-setup'), isEmpty);
      await h.close();
    });

    testWidgets('the failed block\'s Try again is disabled while the switch '
        'is saving', (tester) async {
      await start(tester, size: wide);
      await h.openComputerUse();
      await startInstall(tester);
      world
        ..installRunning = false
        ..installExit = 1;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      world.server.onRequest('PUT', '/api/tools/toolsets/computer_use', (
        _,
      ) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'name': 'computer_use'});
      });

      final rowSwitch = find.descendant(
        of: find.byKey(const ValueKey('tool-row-computer_use')),
        matching: find.byType(ToolsSwitch),
      );
      await tester.tap(rowSwitch);
      await tester.pump(const Duration(milliseconds: 100));
      // A confirmation may come first; answer it.
      if (find.text('Switch on').evaluate().isNotEmpty) {
        await tester.tap(find.text('Switch on'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      final tryAgain = find.widgetWithText(FilledButton, 'Try again');
      expect(tester.widget<FilledButton>(tryAgain).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      await h.close();
    });
  });

  testWidgets('a model list goes with a profile change and a late pick '
      'sends nothing', (tester) async {
    final profile = ValueNotifier('work');
    addTearDown(profile.dispose);
    await start(tester, profile: profile);
    await h.openImages();
    await h.tapText('Model');
    expect(find.text('Fine Two'), findsOneWidget);

    profile.value = 'home';
    await tester.pumpAndSettle();

    expect(find.text('Fine Two'), findsNothing);
    expect(
      world.server.requestsTo('PUT', '/api/tools/toolsets/image_gen/model'),
      isEmpty,
    );
    await h.close();
  });

  testWidgets('Advanced offers the install step under its own header, and '
      'only once the key is saved', (tester) async {
    await start(tester, prepare: (w) => w.searchCoInstall = true);
    await h.openWeb();
    await h.tapText('Use different providers for search and extract');
    // The key is still to type: no install step yet.
    expect(find.text('Install on server'), findsNothing);
    await h.close();

    await start(
      tester,
      prepare: (w) {
        w
          ..searchCoInstall = true
          ..webKeySet = true;
      },
    );
    await h.openWeb();
    await h.tapText('Change setup');
    await h.tapText('Use different providers for search and extract');
    // Its own header, and the step offered again for a ready provider.
    expect(find.text('Install on server'), findsOneWidget);
    expect(find.text('Run the install step again'), findsOneWidget);
    await h.close();
  });

  testWidgets('a second question asked before the first one is on screen '
      'answers no and opens no second dialog', (tester) async {
    late ToolsAsker asker;
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            host = context;
            return const SizedBox();
          },
        ),
      ),
    );
    asker = ToolsAsker(context: () => host);
    addTearDown(asker.dispose);
    final question = toolsetInstallStepQuestion(AppLocalizations.of(host));

    final first = asker.ask(question);
    final second = await asker.ask(question);
    await tester.pumpAndSettle();

    expect(second, isFalse);
    expect(find.text('Install on your server?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await first, isFalse);
  });
}
