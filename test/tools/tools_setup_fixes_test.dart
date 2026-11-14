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

    testWidgets('a provider with keys and an install step that never ran '
        'offers "Install on server" under Advanced', (tester) async {
      await start(tester, prepare: (w) => w.searchCoInstall = true);
      await h.openWeb();

      // Save is the only filled button.
      expect(
        find.widgetWithText(FilledButton, 'Install on server'),
        findsNothing,
      );
      await h.tapText('Use different providers for search and extract');
      expect(find.text('Install on server'), findsOneWidget);
      expect(find.text('Run the install step again'), findsNothing);
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
