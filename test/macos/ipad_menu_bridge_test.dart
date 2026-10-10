import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/macos/mac_menu_bar.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import '../support/recorded_events.dart';

const _channel = MethodChannel('hermes_app/menu');

/// Plays the iOS runner's side of the menu channel.
class FakeRunnerMenu {
  FakeRunnerMenu(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls.add(call);
      final fail = failWith;
      if (fail != null) throw fail;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
  }

  final WidgetTester tester;
  final calls = <MethodCall>[];
  Exception? failWith;

  List<MethodCall> named(String method) => [
    for (final call in calls)
      if (call.method == method) call,
  ];

  Map<Object?, Object?> get lastState {
    final states = named('setState');
    return (states.last.arguments as Map)['states'] as Map<Object?, Object?>;
  }

  bool enabled(String command) =>
      (lastState[command]! as Map)['enabled']! as bool;

  String? title(String command) =>
      (lastState[command]! as Map)['title'] as String?;

  /// The runner reporting that a menu item or key was used.
  Future<void> choose(String command) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(MethodCall('invoke', command)),
      (_) {},
    );
    await tester.pump();
  }
}

void main() {
  late BreadcrumbTrail trail;
  late RecordedEvents events;

  setUp(() {
    trail = BreadcrumbTrail(capacity: 50);
    events = RecordedEvents();
  });

  late HermesRepositories repositories;

  setUp(() {
    repositories = HermesRepositories(
      FakeHermesServer().client(),
      telemetry: events.connection({}),
    );
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    TargetPlatform platform = TargetPlatform.iOS,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          Provider<HermesRepositories?>.value(value: repositories),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(platform: platform),
          builder: (context, child) =>
              MacMenuBar(navigatorKey: navigatorKey, child: child!),
          home: home,
        ),
      ),
    );
    await tester.pump();
  }

  Future<FakeRunnerMenu> pump(
    WidgetTester tester,
    Widget home, {
    TargetPlatform platform = TargetPlatform.iOS,
    Exception? failWith,
  }) async {
    final runner = FakeRunnerMenu(tester)..failWith = failWith;
    await pumpApp(tester, home, platform: platform);
    return runner;
  }

  testWidgets('sends the iPad layout once', (tester) async {
    final runner = await pump(tester, const SizedBox());
    final layouts = runner.named('setLayout');
    expect(layouts, hasLength(1));
    final sections = ((layouts.single.arguments as Map)['sections'] as List)
        .cast<Map<Object?, Object?>>();
    expect(sections.map((s) => s['id']), [
      'hermes',
      'file',
      'view',
      'chat',
      'help',
    ]);
    final file = sections.firstWhere((s) => s['id'] == 'file');
    expect(file['label'], 'File');
    expect(file['groups'], [
      [
        {
          'command': 'newChat',
          'label': 'New Chat',
          'input': 'n',
          'modifiers': ['command'],
        },
      ],
    ]);
    final chat = sections.firstWhere((s) => s['id'] == 'chat');
    final pin = ((chat['groups'] as List)[1] as List).first as Map;
    expect(pin['input'], 'p');
    expect(pin['modifiers'], ['command', 'shift']);
    final delete = ((chat['groups'] as List)[2] as List).last as Map;
    expect(delete['command'], 'deleteThread');
    expect(delete.containsKey('input'), isFalse);
  });

  testWidgets('keeps the layout when the registry changes', (tester) async {
    final runner = await pump(
      tester,
      MacCommandScope(
        commands: {MacCommand.newChat: MacCommandHandler(() {})},
        child: const SizedBox(),
      ),
    );
    expect(runner.named('setLayout'), hasLength(1));
  });

  testWidgets('sends nothing with Mac chrome', (tester) async {
    MacWindow.enabled = true;
    addTearDown(() => MacWindow.enabled = false);
    final runner = await pump(
      tester,
      const SizedBox(),
      platform: TargetPlatform.macOS,
    );
    expect(runner.calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('sends nothing with Material chrome', (tester) async {
    final runner = await pump(
      tester,
      const SizedBox(),
      platform: TargetPlatform.android,
    );
    expect(runner.calls, isEmpty);
  });

  testWidgets('sends the enabled flags and titles of the screen in front', (
    tester,
  ) async {
    final runner = await pump(
      tester,
      MacCommandScope(
        commands: {
          MacCommand.newChat: MacCommandHandler(() {}, title: 'New Task'),
          MacCommand.pinThread: MacCommandHandler(() {}, title: 'Unpin'),
          MacCommand.renameThread: const MacCommandHandler(null),
        },
        child: const SizedBox(),
      ),
    );
    expect(runner.enabled('newChat'), isTrue);
    expect(runner.title('newChat'), 'New Task');
    expect(runner.enabled('pinThread'), isTrue);
    expect(runner.title('pinThread'), 'Unpin');
    expect(runner.enabled('renameThread'), isFalse);
    expect(runner.enabled('find'), isFalse);
    expect(runner.lastState.keys, isNot(contains('closeWindow')));
  });

  testWidgets('a scope that goes away disables its commands', (tester) async {
    late StateSetter rebuild;
    var shown = true;
    final runner = await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return shown
              ? MacCommandScope(
                  commands: {MacCommand.find: MacCommandHandler(() {})},
                  child: const SizedBox(),
                )
              : const SizedBox();
        },
      ),
    );
    expect(runner.enabled('find'), isTrue);
    rebuild(() => shown = false);
    await tester.pump();
    await tester.pump();
    expect(runner.enabled('find'), isFalse);
  });

  testWidgets('a hidden page offers nothing', (tester) async {
    final runner = await pump(
      tester,
      Visibility(
        visible: false,
        maintainState: true,
        child: MacCommandScope(
          commands: {MacCommand.find: MacCommandHandler(() {})},
          child: const SizedBox(),
        ),
      ),
    );
    expect(runner.enabled('find'), isFalse);
  });

  testWidgets('a command picked on the runner runs its handler once', (
    tester,
  ) async {
    var created = 0;
    final runner = await pump(
      tester,
      MacCommandScope(
        commands: {MacCommand.newChat: MacCommandHandler(() => created++)},
        child: const SizedBox(),
      ),
    );
    await runner.choose('newChat');
    expect(created, 1);
  });

  testWidgets('a command nobody offers, or that is unknown, does nothing', (
    tester,
  ) async {
    var created = 0;
    final runner = await pump(
      tester,
      MacCommandScope(
        commands: {
          MacCommand.newChat: MacCommandHandler(() => created++),
          MacCommand.pinThread: const MacCommandHandler(null),
        },
        child: const SizedBox(),
      ),
    );
    await runner.choose('pinThread');
    await runner.choose('nonsense');
    expect(created, 0);
    expect(trail.recent.where((c) => c.name == 'menu.command'), isEmpty);
  });

  group('observability', () {
    testWidgets('a command adds a breadcrumb with its name and platform only', (
      tester,
    ) async {
      final runner = await pump(
        tester,
        MacCommandScope(
          commands: {MacCommand.newChat: MacCommandHandler(() {})},
          child: const SizedBox(),
        ),
      );
      await runner.choose('newChat');
      final crumbs = trail.recent.where((c) => c.name == 'menu.command');
      expect(crumbs.map((c) => c.attributes), [
        {'command': 'newChat', 'platform': 'ipados'},
      ]);
    });

    testWidgets('a rejected layout is swallowed and logged', (tester) async {
      final runner = await pump(
        tester,
        const SizedBox(),
        failWith: PlatformException(code: 'boom'),
      );
      expect(tester.takeException(), isNull);
      expect(runner.named('setLayout'), hasLength(1));
      expect(
        events.named('ipad_menu.sync_failed'),
        contains(
          equals({'operation': 'layout', 'error.type': 'PlatformException'}),
        ),
      );
    });

    testWidgets('a rejected state update is logged', (tester) async {
      late StateSetter rebuild;
      var shown = false;
      final runner = await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return shown
                ? MacCommandScope(
                    commands: {MacCommand.find: MacCommandHandler(() {})},
                    child: const SizedBox(),
                  )
                : const SizedBox();
          },
        ),
      );
      runner.failWith = PlatformException(code: 'boom');
      rebuild(() => shown = true);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        events.named('ipad_menu.sync_failed'),
        contains(
          equals({'operation': 'state', 'error.type': 'PlatformException'}),
        ),
      );
    });

    testWidgets('a runner without the channel is logged as a failure', (
      tester,
    ) async {
      await pump(tester, const SizedBox(), failWith: MissingPluginException());
      expect(tester.takeException(), isNull);
      expect(events.named('ipad_menu.sync_failed').first, {
        'operation': 'layout',
        'error.type': 'MissingPluginException',
      });
    });
  });
}
