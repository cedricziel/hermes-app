import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';

import 'hermes_plugin_manager_repository_test.dart'
    show memoryOption, providersHub;
import 'support/fake_hermes_server.dart';

const _hub = '/api/dashboard/plugins/hub';
const _save = '/api/dashboard/plugin-providers';
const _brvInstall = 'curl -fsSL https://byterover.dev/install.sh | sh';

/// The Plugins screen's Providers tab against a fake dashboard.
void main() {
  late FakeHermesServer server;
  final events = <String>[];

  Map<String, Object?> hub({
    String memory = 'honcho',
    String engine = 'compressor',
    List<Object?>? engines,
  }) => providersHub(
    memory: memory,
    memoryOptions: [
      memoryOption('honcho', description: 'Honcho memory'),
      memoryOption('holographic'),
      memoryOption('mem0', status: 'needs_config', env: ['MEM0_API_KEY']),
      memoryOption(
        'byterover',
        status: 'unavailable',
        external: [
          {'name': 'brv', 'install': _brvInstall, 'check': 'brv --version'},
        ],
        pip: ['byterover-sdk'],
      ),
      memoryOption('retaindb', status: 'unavailable'),
    ],
    engine: engine,
    engines:
        engines ??
        [
          {'name': 'compressor', 'description': 'Default engine'},
          {'name': 'lossless', 'description': 'Keeps every message'},
        ],
  );

  setUp(() {
    events.clear();
    server = FakeHermesServer()..on('GET', _hub, hub());
  });

  Future<void> pump(WidgetTester tester, {double width = 400}) async {
    tester.view
      ..physicalSize = Size(width, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PluginsScreen(
          repository: HermesPluginManagerRepository(server.client().raw),
          events: (name, [attributes = const {}]) => events.add(name),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openProviders(WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(Tab, 'Providers'));
    await tester.pumpAndSettle();
  }

  RadioListTile<String> radio(WidgetTester tester, String key) =>
      tester.widget<RadioListTile<String>>(find.byKey(Key(key)));

  bool selected(WidgetTester tester, String key) {
    final tile = radio(tester, key);
    return RadioGroup.maybeOf<String>(tester.element(find.byKey(Key(key))))
            ?.groupValue ==
        tile.value;
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('providers-save')));

  Map<String, Object?> lastSaved() =>
      jsonBody(server.requestsTo('PUT', _save).last)! as Map<String, Object?>;

  group('tab', () {
    testWidgets('is third, and asks for nothing until it is opened', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(Tab), findsNWidgets(3));
      expect(find.widgetWithText(Tab, 'Providers'), findsOneWidget);
      expect(server.requestsTo('GET', _hub), hasLength(1));

      await tester.tap(find.widgetWithText(Tab, 'Providers'));
      await tester.pumpAndSettle();
      expect(server.requestsTo('GET', _hub), hasLength(2));

      await tester.tap(find.widgetWithText(Tab, 'Installed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Providers'));
      await tester.pumpAndSettle();
      expect(server.requestsTo('GET', _hub), hasLength(2));
    });

    testWidgets('shows a spinner while it loads', (tester) async {
      await pump(tester);
      final gate = Completer<void>();
      server.onRequest('GET', _hub, (_) async {
        await gate.future;
        return (status: 200, body: hub());
      });

      await tester.tap(find.widgetWithText(Tab, 'Providers'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('offers Retry after a failed load', (tester) async {
      await pump(tester);
      server.on('GET', _hub, {'detail': 'boom'}, status: 500);
      await tester.tap(find.widgetWithText(Tab, 'Providers'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load provider settings'), findsOneWidget);

      server.on('GET', _hub, hub());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('memory-honcho')), findsOneWidget);
    });

    testWidgets('says the settings are unavailable on an old server', (
      tester,
    ) async {
      await pump(tester);
      server.on('GET', _hub, {'detail': 'Not Found'}, status: 404);
      await tester.tap(find.widgetWithText(Tab, 'Providers'));
      await tester.pumpAndSettle();

      expect(
        find.text('The provider settings are not available on this server'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('memory provider', () {
    testWidgets('lists Built-in first and selects the one in use', (
      tester,
    ) async {
      await openProviders(tester);

      expect(
        tester.getTopLeft(find.byKey(const Key('memory-builtin'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('memory-honcho'))).dy),
      );
      expect(selected(tester, 'memory-honcho'), isTrue);
      expect(selected(tester, 'memory-builtin'), isFalse);
      expect(find.text('Honcho memory'), findsOneWidget);
    });

    testWidgets('selects Built-in when the server reports none', (
      tester,
    ) async {
      server.on('GET', _hub, hub(memory: ''));

      await openProviders(tester);

      expect(selected(tester, 'memory-builtin'), isTrue);
    });

    testWidgets('marks each provider Ready, Needs setup or Unavailable', (
      tester,
    ) async {
      await openProviders(tester);

      expect(find.text('Ready'), findsNWidgets(2));
      expect(find.text('Needs setup'), findsOneWidget);
      expect(find.text('Unavailable'), findsNWidgets(2));
    });

    testWidgets('lets the user pick a ready provider but not another', (
      tester,
    ) async {
      await openProviders(tester);

      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();
      expect(selected(tester, 'memory-holographic'), isTrue);

      await tester.tap(
        find.byKey(const Key('memory-mem0')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(selected(tester, 'memory-mem0'), isFalse);
      expect(selected(tester, 'memory-holographic'), isTrue);
      expect(radio(tester, 'memory-mem0').enabled, isFalse);
    });

    testWidgets(
      'keeps the provider in use choosable even when it is not ready',
      (tester) async {
        server.on('GET', _hub, hub(memory: 'mem0'));

        await openProviders(tester);

        expect(selected(tester, 'memory-mem0'), isTrue);
        expect(radio(tester, 'memory-mem0').enabled, isTrue);
      },
    );

    testWidgets('says what a provider needs, and that setup is on the server', (
      tester,
    ) async {
      await openProviders(tester);
      await tester.ensureVisible(find.byKey(const Key('needs-byterover')));
      await tester.tap(find.byKey(const Key('needs-byterover')));
      await tester.pumpAndSettle();

      expect(find.text('brv'), findsOneWidget);
      expect(find.text(_brvInstall), findsOneWidget);
      expect(find.text('byterover-sdk'), findsOneWidget);
      expect(find.text('Set this up on the server.'), findsOneWidget);
    });

    testWidgets('lists the environment variables by name', (tester) async {
      await openProviders(tester);
      await tester.ensureVisible(find.byKey(const Key('needs-mem0')));
      await tester.tap(find.byKey(const Key('needs-mem0')));
      await tester.pumpAndSettle();

      expect(find.text('MEM0_API_KEY'), findsOneWidget);
    });

    testWidgets('says so when a provider names no requirements', (
      tester,
    ) async {
      await openProviders(tester);
      await tester.ensureVisible(find.byKey(const Key('needs-retaindb')));
      await tester.tap(find.byKey(const Key('needs-retaindb')));
      await tester.pumpAndSettle();

      expect(
        find.text('The server did not say what it needs.'),
        findsOneWidget,
      );
    });

    testWidgets('offers no requirements for a ready provider', (tester) async {
      await openProviders(tester);

      expect(find.byKey(const Key('needs-honcho')), findsNothing);
    });

    group('copying', () {
      final copied = <String>[];

      setUp(() {
        copied.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied.add((call.arguments as Map)['text'] as String);
              }
              return null;
            });
      });

      tearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      testWidgets('puts only the install command on the clipboard', (
        tester,
      ) async {
        await openProviders(tester);
        await tester.ensureVisible(find.byKey(const Key('needs-byterover')));
        await tester.tap(find.byKey(const Key('needs-byterover')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('copy-install-brv')));
        await tester.pumpAndSettle();

        expect(copied, [_brvInstall]);
        expect(find.text('Copied'), findsOneWidget);
      });
    });
  });

  group('context engine', () {
    testWidgets('lists the engines with the one in use selected', (
      tester,
    ) async {
      await openProviders(tester);

      expect(selected(tester, 'engine-compressor'), isTrue);
      expect(selected(tester, 'engine-lossless'), isFalse);
      expect(find.text('Keeps every message'), findsOneWidget);
    });

    testWidgets('shows an engine in use that the server does not list', (
      tester,
    ) async {
      server.on('GET', _hub, hub(engine: 'custom-one'));

      await openProviders(tester);

      expect(selected(tester, 'engine-custom-one'), isTrue);
    });

    testWidgets('offers no choice when the server lists no engines', (
      tester,
    ) async {
      server.on('GET', _hub, hub(engines: []));

      await openProviders(tester);

      expect(
        find.text('No other context engines are available on this server'),
        findsOneWidget,
      );
      expect(find.text('compressor'), findsOneWidget);
      expect(find.byKey(const Key('engine-compressor')), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('is disabled until a choice changes', (tester) async {
      await openProviders(tester);
      expect(saveButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('memory-honcho')));
      await tester.pumpAndSettle();
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('sends only what changed, says so, and reloads', (
      tester,
    ) async {
      server.on('PUT', _save, {'ok': true});
      await openProviders(tester);
      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();
      server.on('GET', _hub, hub(memory: 'holographic'));

      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pumpAndSettle();

      expect(lastSaved(), {'memory_provider': 'holographic'});
      expect(find.text('Saved. Applies to new chats.'), findsOneWidget);
      expect(selected(tester, 'memory-holographic'), isTrue);
      expect(saveButton(tester).onPressed, isNull);
      expect(events, ['plugins.providers.save.ok']);
    });

    testWidgets('sends an empty string for Built-in and the engine', (
      tester,
    ) async {
      server.on('PUT', _save, {'ok': true});
      await openProviders(tester);
      await tester.tap(find.byKey(const Key('memory-builtin')));
      await tester.tap(find.byKey(const Key('engine-lossless')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pumpAndSettle();

      expect(lastSaved(), {
        'memory_provider': '',
        'context_engine': 'lossless',
      });
    });

    testWidgets('shows the server\'s reason and keeps the choices', (
      tester,
    ) async {
      server.on('PUT', _save, {
        'detail': "Memory provider 'holographic' is not ready.",
      }, status: 400);
      await openProviders(tester);
      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pumpAndSettle();

      expect(
        find.text("Memory provider 'holographic' is not ready."),
        findsOneWidget,
      );
      expect(selected(tester, 'memory-holographic'), isTrue);
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('says so when the server cannot be reached', (tester) async {
      server.onRequest(
        'PUT',
        _save,
        (_) => throw const SocketException('no route to host'),
      );
      await openProviders(tester);
      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pumpAndSettle();

      expect(find.text('Could not save provider settings'), findsOneWidget);
      expect(selected(tester, 'memory-holographic'), isTrue);
    });

    testWidgets('shows progress and ignores a second tap while it runs', (
      tester,
    ) async {
      final gate = Completer<void>();
      server.onRequest('PUT', _save, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true});
      });
      await openProviders(tester);
      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pump();

      expect(saveButton(tester).onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('providers-save')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(server.requestsTo('PUT', _save), hasLength(1));
    });
  });

  group('refreshing', () {
    testWidgets('replaces unsaved choices with the server\'s', (tester) async {
      await openProviders(tester);
      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const Key('providers-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(selected(tester, 'memory-honcho'), isTrue);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('says so when a refresh fails and keeps what is shown', (
      tester,
    ) async {
      await openProviders(tester);
      server.on('GET', _hub, {'detail': 'boom'}, status: 500);

      await tester.fling(
        find.byKey(const Key('providers-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh provider settings'), findsOneWidget);
      expect(find.byKey(const Key('memory-honcho')), findsOneWidget);
    });
  });
}
