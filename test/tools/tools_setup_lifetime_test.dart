import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/toolset_installs.dart';
import 'package:hermes_app/src/tools/widgets/toolset_model_sheet.dart';
import 'package:hermes_app/src/tools/widgets/tools_switch.dart';

import 'tools_setup_harness.dart';
import 'tools_setup_world.dart';

/// The setup controllers live as long as the screen: a write goes on and keeps
/// its toolset's switch locked when its panel is closed, its result waits
/// once, a profile change drops what is in flight, and every writer of a
/// toolset locks the others.
void main() {
  late SetupWorld world;
  late SetupHarness h;

  const web = '/api/tools/toolsets/web';
  const backend = '/api/tools/terminal/backend';

  Future<void> start(
    WidgetTester tester, {
    Size size = wide,
    void Function(SetupWorld)? prepare,
    ValueNotifier<String>? profile,
    ToolsetInstalls? installs,
  }) async {
    world = SetupWorld();
    prepare?.call(world);
    h = SetupHarness(tester, world);
    await h.pump(size: size, profile: profile, installs: installs);
  }

  Finder listText(String sentence) => find.descendant(
    of: find.byKey(const Key('tools-list')),
    matching: find.text(sentence),
  );

  Future<void> openFromList(WidgetTester tester, String sentence) async {
    await tester.ensureVisible(listText(sentence));
    await tester.tap(listText(sentence));
    await tester.pump(const Duration(milliseconds: 200));
  }

  const webText = 'Look things up on the web and read pages.';
  const todoText = 'Keep a to-do list while working.';
  const terminalText = 'Run commands on the machine where Hermes runs.';
  const computerText =
      "See a desktop's screen and move its mouse and keyboard.";

  Finder rowSwitch(String name) => find.descendant(
    of: find.byKey(ValueKey('tool-row-$name')),
    matching: find.byType(ToolsSwitch),
  );

  bool locked(WidgetTester tester, String name) =>
      tester.widget<ToolsSwitch>(rowSwitch(name)).onChanged == null;

  group('a result waits once', () {
    testWidgets('a save that settled while its panel was closed shows on '
        'return and not on the visit after', (tester) async {
      await start(tester);
      final gate = Completer<void>();
      world.server.onRequest('PUT', '$web/env', (_) async {
        await gate.future;
        world.webKeySet = true;
        return (status: 200, body: {'ok': true, 'name': 'web', 'saved': []});
      });
      await h.type(typedKey);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));
      await openFromList(tester, todoText);
      gate.complete();
      await tester.pumpAndSettle();

      await openFromList(tester, webText);
      await tester.pumpAndSettle();
      expect(find.text('Saved.'), findsOneWidget);

      await openFromList(tester, todoText);
      await tester.pumpAndSettle();
      await openFromList(tester, webText);
      await tester.pumpAndSettle();
      expect(find.text('Saved.'), findsNothing);
      await h.close();
    });

    testWidgets('a lost answer checks while the panel is closed and says '
        'so on return', (tester) async {
      await start(tester);
      world.loseAnswer('PUT', '$web/env');
      final gate = Completer<void>();
      world.server.onRequest('GET', '$web/config', (_) async {
        await gate.future;
        return (status: 200, body: world.webConfig());
      });
      await h.type(typedKey);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('May have saved. Checking…'), findsOneWidget);

      await openFromList(tester, todoText);
      expect(locked(tester, 'web'), isTrue);
      gate.complete();
      await tester.pumpAndSettle();
      expect(locked(tester, 'web'), isFalse);

      await openFromList(tester, webText);
      await tester.pumpAndSettle();
      expect(
        find.text("The key wasn't saved. Paste it again."),
        findsOneWidget,
      );
      expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));
      await h.close();
    });

    testWidgets('a refused backend pick that ended while its panel was '
        'closed shows once', (tester) async {
      await start(tester);
      final gate = Completer<void>();
      world.server.onRequest('PUT', backend, (_) async {
        await gate.future;
        return (status: 400, body: {'detail': 'Unknown backend.'});
      });
      await openFromList(tester, terminalText);
      await tester.pumpAndSettle();
      await tester.ensureVisible(h.provider('docker'));
      await tester.tap(h.provider('docker'));
      await tester.pump(const Duration(milliseconds: 100));
      await openFromList(tester, todoText);
      expect(locked(tester, 'terminal'), isTrue);
      gate.complete();
      await tester.pumpAndSettle();
      expect(locked(tester, 'terminal'), isFalse);

      await openFromList(tester, terminalText);
      await tester.pumpAndSettle();
      expect(find.text('Unknown backend.'), findsOneWidget);
      await openFromList(tester, todoText);
      await openFromList(tester, terminalText);
      await tester.pumpAndSettle();
      expect(find.text('Unknown backend.'), findsNothing);
      await h.close();
    });

    testWidgets('a grant that ended while its panel was closed is read '
        'again and the switch is released', (tester) async {
      await start(
        tester,
        prepare: (w) => w
          ..driverInstalled = true
          ..screenRecording = false,
      );
      await openFromList(tester, computerText);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Allow access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow access').last);
      await tester.pump(const Duration(milliseconds: 100));
      await openFromList(tester, todoText);
      expect(locked(tester, 'computer_use'), isTrue);

      world
        ..grantRunning = false
        ..grantExit = 0
        ..screenRecording = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(locked(tester, 'computer_use'), isFalse);

      await openFromList(tester, computerText);
      await tester.pumpAndSettle();
      expect(find.text('Not allowed'), findsNothing);
      await h.close();
    });
  });

  group('the screen and the profile while a write is out', () {
    testWidgets('closing the screen mid-write leaves nothing running', (
      tester,
    ) async {
      await start(tester);
      final gate = Completer<void>();
      world.server.onRequest('PUT', '$web/env', (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'name': 'web', 'saved': []});
      });
      await h.type(typedKey);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));

      await h.close();
      gate.complete();
      await tester.pump(const Duration(seconds: 15));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a lost answer still checking when the screen closes ends '
        'quietly', (tester) async {
      await start(tester);
      world.loseAnswer('PUT', '$web/env');
      final gate = Completer<void>();
      world.server.onRequest('GET', '$web/config', (_) async {
        await gate.future;
        return (status: 200, body: world.webConfig());
      });
      await h.type(typedKey);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 200));

      await h.close();
      gate.complete();
      await tester.pump(const Duration(seconds: 15));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a profile change drops a write in flight with its panel '
        'closed: lock released, late answer dropped', (tester) async {
      final profile = ValueNotifier('work');
      addTearDown(profile.dispose);
      await start(tester, profile: profile);
      final gate = Completer<void>();
      world.server.onRequest('PUT', '$web/env', (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'name': 'web', 'saved': []});
      });
      await h.type(typedKey);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));
      await openFromList(tester, todoText);
      expect(locked(tester, 'web'), isTrue);

      profile.value = 'home';
      await tester.pumpAndSettle();
      final before = world.server.requests.length;
      gate.complete();
      await tester.pumpAndSettle();

      expect(locked(tester, 'web'), isFalse);
      expect(
        world.server.requests
            .skip(before)
            .where((r) => r.queryParameters['profile'] == 'work'),
        isEmpty,
      );
      await h.close();
    });

    testWidgets('a backend pick in flight during a profile change does not '
        'read the list again as if it had landed', (tester) async {
      final profile = ValueNotifier('work');
      addTearDown(profile.dispose);
      await start(tester, profile: profile);
      final gate = Completer<void>();
      world.server.onRequest('PUT', backend, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'backend': 'docker'});
      });
      await openFromList(tester, terminalText);
      await tester.pumpAndSettle();
      await tester.ensureVisible(h.provider('docker'));
      await tester.tap(h.provider('docker'));
      await tester.pump(const Duration(milliseconds: 100));

      profile.value = 'home';
      await tester.pumpAndSettle();
      final reads = world.server
          .requestsTo('GET', '/api/tools/toolsets')
          .length;
      gate.complete();
      await tester.pumpAndSettle();

      expect(
        world.server.requestsTo('GET', '/api/tools/toolsets').length,
        reads,
      );
      await h.close();
    });

    testWidgets('a model pick tapped late, after the profile changed, sends '
        'nothing', (tester) async {
      final profile = ValueNotifier('work');
      addTearDown(profile.dispose);
      await start(tester, size: phone, profile: profile);
      await h.openImages();
      await h.tapText('Model');
      final late = tester
          .widget<ToolsetModelSheet>(find.byType(ToolsetModelSheet))
          .onPick;

      profile.value = 'home';
      await tester.pumpAndSettle();
      late('fine-2');
      await tester.pumpAndSettle();

      expect(
        world.server.requestsTo('PUT', '/api/tools/toolsets/image_gen/model'),
        isEmpty,
      );
      await h.close();
    });
  });

  group('every writer of a toolset locks the others', () {
    testWidgets('a backend pick locks the toolset\'s key save and the other '
        'way round', (tester) async {
      await start(tester, prepare: (w) => w.terminalKeys = true);
      await openFromList(tester, terminalText);
      await tester.pumpAndSettle();
      await h.tapText('Change setup');
      final gate = Completer<void>();
      world.server.onRequest('PUT', backend, (_) async {
        await gate.future;
        world.backend = 'docker';
        return (status: 200, body: {'ok': true, 'backend': 'docker'});
      });
      await h.type(typedKey);
      await tester.ensureVisible(h.provider('docker'));
      await tester.tap(h.provider('docker'));
      await tester.pump(const Duration(milliseconds: 100));

      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      // The other way round: a save in flight locks the backends.
      final keyGate = Completer<void>();
      world.server.onRequest('PUT', '/api/tools/toolsets/terminal/env', (
        _,
      ) async {
        await keyGate.future;
        return (status: 200, body: {'ok': true, 'name': 'terminal'});
      });
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));
      final puts = world.server.requestsTo('PUT', backend).length;
      await tester.ensureVisible(h.provider('local'));
      await tester.tap(h.provider('local'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(world.server.requestsTo('PUT', backend).length, puts);
      keyGate.complete();
      await tester.pumpAndSettle();
      await h.close();
    });

    testWidgets('a running grant disables the failed install\'s Try again', (
      tester,
    ) async {
      final installs = ToolsetInstalls(requestReread: (_) {});
      addTearDown(installs.dispose);
      // Tall, so the long page builds all of its rows.
      await start(tester, size: const Size(1200, 3000), installs: installs);
      await openFromList(tester, computerText);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install').last);
      await tester.pump(const Duration(milliseconds: 100));
      world
        ..installRunning = false
        ..installExit = 1;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);

      // The driver is there now and a permission is missing.
      world
        ..driverInstalled = true
        ..screenRecording = false;
      await openFromList(tester, todoText);
      await tester.pumpAndSettle();
      await openFromList(tester, computerText);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Allow access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow access').last);
      await tester.pump(const Duration(milliseconds: 100));

      final tryAgain = find.widgetWithText(FilledButton, 'Try again');
      expect(tester.widget<FilledButton>(tryAgain).onPressed, isNull);

      world
        ..grantRunning = false
        ..grantExit = 0;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      installs.clear();
      await h.close();
    });
  });
}
