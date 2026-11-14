import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/toolset_installs.dart';
import 'package:hermes_app/src/tools/widgets/tools_switch.dart';

import 'tools_setup_harness.dart';
import 'tools_setup_world.dart';

/// `hermes tools post-setup` may write the config, so a running install locks
/// its toolset's other writers like a write of their own, and they lock the
/// install. Other toolsets are unaffected.
void main() {
  late SetupWorld world;
  late SetupHarness h;
  late ToolsetInstalls installs;

  const web = '/api/tools/toolsets/web';
  const backend = '/api/tools/terminal/backend';
  const webText = 'Look things up on the web and read pages.';
  const todoText = 'Keep a to-do list while working.';
  const computerText =
      "See a desktop's screen and move its mouse and keyboard.";

  HermesToolsRepository repository() =>
      HermesToolsRepository(world.server.client().raw, profile: 'work');

  Future<void> start(
    WidgetTester tester, {
    void Function(SetupWorld)? prepare,
    bool installRunningFirst = false,
    String? toolset,
    String key = 'local_driver',
    Size size = wide,
  }) async {
    world = SetupWorld();
    prepare?.call(world);
    for (final name in ['terminal', 'todo']) {
      world.server.onRequest(
        'POST',
        '/api/tools/toolsets/$name/post-setup',
        (_) => (
          status: 200,
          body: {'ok': true, 'pid': 4242, 'name': 'tools-post-setup'},
        ),
      );
    }
    installs = ToolsetInstalls(requestReread: (_) {});
    addTearDown(installs.dispose);
    if (installRunningFirst) {
      unawaited(installs.startConfirmed(repository(), toolset!, key));
    }
    h = SetupHarness(tester, world);
    await h.pump(size: size, installs: installs);
  }

  Finder rowSwitch(String name) => find.descendant(
    of: find.byKey(ValueKey('tool-row-$name')),
    matching: find.byType(ToolsSwitch),
  );

  bool locked(WidgetTester tester, String name) =>
      tester.widget<ToolsSwitch>(rowSwitch(name)).onChanged == null;

  Future<void> install(
    WidgetTester tester,
    String toolset, {
    String key = 'local_driver',
  }) async {
    unawaited(installs.startConfirmed(repository(), toolset, key));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> endInstall(WidgetTester tester) async {
    world
      ..installRunning = false
      ..installExit = 0;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('a running install locks its toolset\'s switch, key save and '
      'provider pick, and not another toolset', (tester) async {
    await start(tester);
    await install(tester, 'web');

    expect(locked(tester, 'web'), isTrue);
    expect(locked(tester, 'todo'), isFalse);

    // Web's details are the pane: its Save, and a provider pick, wait.
    await h.type(typedKey);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.ensureVisible(h.provider('Local Driver'));
    await tester.tap(h.provider('Local Driver'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(rowSwitch('web'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(world.server.requestsTo('PUT', '$web/env'), isEmpty);
    expect(world.server.requestsTo('PUT', '$web/provider'), isEmpty);
    expect(world.server.requestsTo('PUT', web), isEmpty);

    // Another toolset switches freely meanwhile.
    await tester.tap(rowSwitch('todo'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      world.server.requestsTo('PUT', '/api/tools/toolsets/todo'),
      hasLength(1),
    );

    await endInstall(tester);
    expect(locked(tester, 'web'), isFalse);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await h.close();
  });

  testWidgets('an install that was already running when the screen opened '
      'holds the lock', (tester) async {
    // Todo's details are not open, so its progress does not animate here.
    await start(tester, installRunningFirst: true, toolset: 'todo');
    await tester.pump(const Duration(milliseconds: 100));

    expect(locked(tester, 'todo'), isTrue);
    expect(locked(tester, 'web'), isFalse);

    await endInstall(tester);
    expect(locked(tester, 'todo'), isFalse);
    await h.close();
  });

  testWidgets('a running install of Computer use withholds Allow access', (
    tester,
  ) async {
    await start(
      tester,
      prepare: (w) => w
        ..driverInstalled = true
        ..screenRecording = false,
    );
    await tester.pump();
    await h.open(computerText);
    await install(tester, 'computer_use', key: 'cua_driver');

    final allow = find.widgetWithText(FilledButton, 'Allow access');
    expect(allow, findsNothing);
    expect(locked(tester, 'computer_use'), isTrue);
    expect(
      world.server.requestsTo(
        'POST',
        '/api/tools/computer-use/permissions/grant',
      ),
      isEmpty,
    );

    await endInstall(tester);
    expect(allow, findsOneWidget);
    await h.close();
  });

  testWidgets('a running install of Terminal withholds a backend pick', (
    tester,
  ) async {
    await start(tester);
    await h.open('Run commands on the machine where Hermes runs.');
    await install(tester, 'terminal', key: 'terminal_driver');

    await tester.ensureVisible(h.provider('docker'));
    await tester.tap(h.provider('docker'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));

    expect(world.server.requestsTo('PUT', backend), isEmpty);
    await endInstall(tester);
    await h.close();
  });

  testWidgets('the button\'s own install locks the switch until it ends', (
    tester,
  ) async {
    await start(tester);
    await h.pick('Local Driver');
    await tester.tap(find.widgetWithText(FilledButton, 'Install on server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(world.server.requestsTo('POST', '$web/post-setup'), hasLength(1));
    expect(locked(tester, 'web'), isTrue);
    expect(find.text('Installing on your server…'), findsOneWidget);

    await endInstall(tester);
    expect(locked(tester, 'web'), isFalse);
    expect(find.text(todoText), findsWidgets);
    expect(find.text(webText), findsWidgets);
    await h.close();
  });
}
