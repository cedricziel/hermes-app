import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/widgets/toolset_header.dart';
import 'package:hermes_app/src/tools/widgets/tools_switch.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import '../support/pump_chat.dart' show openSidebarMore;
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart' show newAppLock, workflowPlatform;
import '../tools/tools_setup_world.dart';

/// Setting a toolset up from the real shell: Web with a key (saved, failed,
/// answer lost), an install, where Terminal runs commands, and Computer use
/// on a Mac server. A typed key is an invented value and never shows.
void main() {
  late SetupWorld world;

  const typed = 'abcdefghijklmno';
  const web = '/api/tools/toolsets/web';

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    world = SetupWorld();
    world.server
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work', description: 'Day job'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]))
      ..on('GET', '/api/model/auxiliary', {
        'tasks': <Object?>[],
        'main': {'provider': 'nous', 'model': 'hermes-4'},
      });
  });

  Future<void> pumpShell(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
    TargetPlatform? platform,
    Locale? locale,
  }) async {
    await shots.start(tester, size);
    final auth = ProtectedCatalogAuth(world.server);
    addTearDown(auth.dispose);
    final lock = await newAppLock(tester);
    final base = brightness == Brightness.dark
        ? buildHermesDarkTheme(platform: platform ?? workflowPlatform)
        : buildHermesLightTheme(platform: platform ?? workflowPlatform);
    await tester.pumpWidget(
      shots.frame(
        withAppProviders(
          auth,
          lock: lock,
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: withScreenshotFont(base),
            home: const AppShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTools(WidgetTester tester, {String label = 'Tools'}) async {
    final phone = tester
        .widget<ThreadSidebar>(find.byType(ThreadSidebar))
        .fullPage;
    if (phone) {
      await tester.tap(find.byKey(const Key('shell-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text(label)),
      );
    } else {
      await openSidebarMore(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ThreadSidebar),
          matching: find.text(label),
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> openRow(
    WidgetTester tester,
    String sentence, {
    bool settle = true,
  }) async {
    final finder = find.descendant(
      of: find.byKey(const Key('tools-list')),
      matching: find.text(sentence),
    );
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
  }

  const webText = 'Look things up on the web and read pages.';
  const terminalText = 'Run commands on the machine where Hermes runs.';
  const computerText =
      "See a desktop's screen and move its mouse and keyboard.";

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> typeKey(WidgetTester tester) async {
    await reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).first, typed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final suffix = brightness == Brightness.dark ? '$name-dark' : name;

      testWidgets('$suffix: Web, a key saved', (tester) async {
        final shots = ScreenshotRecorder('tools-setup-key-$suffix');
        await pumpShell(tester, shots, size: size, brightness: brightness);
        await openTools(tester);
        await openRow(tester, webText);
        await shots.capture(tester, 'setup-open');

        await typeKey(tester);
        expect(find.text('15 characters entered'), findsOneWidget);
        await shots.capture(tester, 'typed-hidden');

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Saved.'));
        expect(find.text('Already set'), findsOneWidget);
        await shots.capture(tester, 'saved');
      });

      testWidgets('$suffix: Web, a key that failed to save', (tester) async {
        final shots = ScreenshotRecorder('tools-setup-failed-$suffix');
        await pumpShell(tester, shots, size: size, brightness: brightness);
        world.server.on('PUT', '$web/env', {'detail': 'x'}, status: 500);
        await openTools(tester);
        await openRow(tester, webText);
        await typeKey(tester);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text("Couldn't save the key. Try again."));
        await shots.capture(tester, 'failed');
        expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));
      });

      testWidgets('$suffix: Web, the answer to a save lost', (tester) async {
        final shots = ScreenshotRecorder('tools-setup-lost-$suffix');
        await pumpShell(tester, shots, size: size, brightness: brightness);
        world.loseAnswer('PUT', '$web/env');
        await openTools(tester);
        await openRow(tester, webText);
        await typeKey(tester);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.text("The key wasn't saved. Paste it again."),
        );
        await shots.capture(tester, 'not-saved');
        expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));
      });

      testWidgets('$suffix: Web, lost answer, checking and couldn\'t confirm', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('tools-setup-checking-$suffix');
        await pumpShell(tester, shots, size: size, brightness: brightness);
        await openTools(tester);
        await openRow(tester, webText);
        world.loseAnswer('PUT', '$web/env');
        world.server.onRequest('GET', '$web/config', (_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return (status: 200, body: world.webConfig());
        });
        await typeKey(tester);

        await tester.tap(find.text('Save'));
        await tester.pump(const Duration(milliseconds: 200));
        await reveal(tester, find.text('May have saved. Checking…'));
        await shots.capture(tester, 'checking');
        await tester.pump(const Duration(seconds: 11));
        await reveal(tester, find.textContaining("Couldn't confirm."));
        await shots.capture(tester, 'couldnt-confirm');
        await tester.pump(const Duration(seconds: 30));
      });

      testWidgets('$suffix: Computer use, install on the server', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('tools-setup-install-$suffix');
        await pumpShell(tester, shots, size: size, brightness: brightness);
        await openTools(tester);
        await openRow(tester, computerText);
        await reveal(tester, find.text('Install on server'));
        await shots.capture(tester, 'needs-install');

        await tester.tap(
          find.widgetWithText(FilledButton, 'Install on server'),
        );
        await tester.pumpAndSettle();
        await shots.capture(tester, 'question');
        expect(
          world.server.requestsTo(
            'POST',
            '/api/tools/toolsets/computer_use/post-setup',
          ),
          isEmpty,
        );

        await tester.tap(find.text('Install').last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await reveal(tester, find.text('Installing on your server…'));
        await shots.capture(tester, 'running');

        world
          ..installRunning = false
          ..installExit = 1
          ..installLines = [
            'Downloading the driver',
            'No space left on device',
          ];
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await reveal(tester, find.text("The install didn't finish."));
        await shots.capture(tester, 'failed');
      });

      testWidgets('$suffix: Terminal, where commands run', (tester) async {
        final shots = ScreenshotRecorder('tools-setup-terminal-$suffix');
        world.backend = 'docker';
        await pumpShell(tester, shots, size: size, brightness: brightness);
        await openTools(tester);
        await openRow(tester, terminalText);
        await reveal(tester, find.text('Where commands run'));
        await shots.capture(tester, 'backends');

        final local = find.byKey(const ValueKey('provider-local'));
        await reveal(tester, local);
        await tester.tap(local);
        await tester.pumpAndSettle();
        expect(
          find.text('Run commands directly on your server?'),
          findsOneWidget,
        );
        expect(
          world.server.requestsTo('PUT', '/api/tools/terminal/backend'),
          isEmpty,
        );
        await shots.capture(tester, 'local-question');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });

      testWidgets('$suffix: Computer use on a Mac server', (tester) async {
        final shots = ScreenshotRecorder('tools-setup-computer-$suffix');
        world
          ..driverInstalled = true
          ..screenRecording = false;
        await pumpShell(tester, shots, size: size, brightness: brightness);
        await openTools(tester);
        await openRow(tester, computerText);
        await reveal(tester, find.text('Readiness'));
        await shots.capture(tester, 'readiness');
        await reveal(tester, find.widgetWithText(FilledButton, 'Allow access'));
        await shots.capture(tester, 'allow-access');

        await tester.tap(find.widgetWithText(FilledButton, 'Allow access'));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'question');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
    }
  }

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: the setup is locked while the switch is saving', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('tools-setup-busy-$name');
      await pumpShell(tester, shots, size: size);
      await openTools(tester);
      await openRow(tester, webText);
      await typeKey(tester);
      final gate = Completer<void>();
      world.server.onRequest('PUT', web, (_) async {
        await gate.future;
        return (
          status: 200,
          body: {'ok': true, 'name': 'web', 'enabled': false},
        );
      });
      final switchOf = find.descendant(
        of: find.byType(ToolsetHeader).first,
        matching: find.byType(ToolsSwitch),
      );
      if (name == 'phone') {
        await tester.drag(find.byType(ListView).last, const Offset(0, 3000));
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        await tester.drag(find.byType(ListView).last, const Offset(0, 3000));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.tap(switchOf);
      await tester.pump(const Duration(milliseconds: 300));
      await shots.capture(tester, 'header-saving');
      await reveal(tester, find.byType(TextField));
      await shots.capture(tester, 'save-disabled');
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('$name: keys and an install step that never ran', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('tools-setup-combo-$name');
      world.searchCoInstall = true;
      await pumpShell(tester, shots, size: size);
      await openTools(tester);
      await openRow(tester, webText);
      final toggle = find.text(
        'Use different providers for search and extract',
      );
      await reveal(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Install on server'));
      await shots.capture(tester, 'advanced');
    });
  }

  testWidgets('phone, German: Web setup and Terminal', (tester) async {
    final shots = ScreenshotRecorder('tools-setup-de');
    world.backend = 'docker';
    await pumpShell(tester, shots, size: phoneSize, locale: const Locale('de'));
    await openTools(tester, label: 'Tools');
    await openRow(tester, 'Im Web nachschlagen und Seiten lesen.');
    await shots.capture(tester, 'web-setup');
    await typeKey(tester);
    await shots.capture(tester, 'web-typed');
    world.server.on('PUT', '$web/env', {'detail': 'x'}, status: 500);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    await reveal(tester, find.textContaining('konnte nicht gespeichert'));
    await shots.capture(tester, 'web-failed');
  });
}
