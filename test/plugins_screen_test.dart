import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:provider/provider.dart';

import 'hermes_plugin_manager_repository_test.dart' show hubBody, hubRow;
import 'support/fake_hermes_server.dart';

const _hub = '/api/dashboard/plugins/hub';
const _agent = '/api/dashboard/agent-plugins';

void main() {
  late FakeHermesServer server;
  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        _hub,
        hubBody([
          hubRow('netbox', description: 'Query NetBox'),
          hubRow('kanban', source: 'bundled', canRemove: false),
        ]),
      );
  });

  Future<void> pump(
    WidgetTester tester, {
    double width = 400,
    bool settle = true,
  }) async {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PluginsScreen(
          repository: HermesPluginManagerRepository(server.client().raw),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Finder inDetail(Finder finder) => find.descendant(
    of: find.byKey(const Key('plugin-detail')),
    matching: finder,
  );

  group('list', () {
    testWidgets('shows a spinner, then the plugins in the server\'s order', (
      tester,
    ) async {
      final gate = Completer<void>();
      server.onRequest('GET', _hub, (_) async {
        await gate.future;
        return (status: 200, body: hubBody([hubRow('zeta'), hubRow('alpha')]));
      });

      await pump(tester, settle: false);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.getTopLeft(find.text('zeta')).dy,
        lessThan(tester.getTopLeft(find.text('alpha')).dy),
      );
    });

    testWidgets('says so when there are no plugins', (tester) async {
      server.on('GET', _hub, hubBody([]));

      await pump(tester);

      expect(find.text('No plugins installed'), findsOneWidget);
    });

    testWidgets('offers Retry after a failed first load', (tester) async {
      server.on('GET', _hub, {'detail': 'boom'}, status: 500);
      await pump(tester);
      expect(find.text('Could not load plugins'), findsOneWidget);

      server.on('GET', _hub, hubBody([hubRow('netbox')]));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('netbox'), findsOneWidget);
      expect(find.text('Could not load plugins'), findsNothing);
    });

    testWidgets('says the list is unavailable on an old server', (
      tester,
    ) async {
      server.on('GET', _hub, {'detail': 'Not Found'}, status: 404);

      await pump(tester);

      expect(
        find.text('The plugin list is not available on this server'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('marks status, source, login and removal on each row', (
      tester,
    ) async {
      server.on(
        'GET',
        _hub,
        hubBody([
          hubRow('on', status: 'enabled'),
          hubRow('off', status: 'disabled'),
          hubRow('idle', status: 'inactive'),
          hubRow('kanban', source: 'bundled'),
          hubRow('spotify', authRequired: true),
          hubRow('old', removedReason: 'unsafe network call'),
        ]),
      );

      await pump(tester);

      expect(find.text('Enabled'), findsNWidgets(4));
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Bundled'), findsOneWidget);
      expect(find.text('Needs login'), findsOneWidget);
      expect(find.text('Removed: unsafe network call'), findsOneWidget);
    });

    testWidgets('shortens a long description in the list, not in the details', (
      tester,
    ) async {
      final long = List.filled(40, 'word').join(' ');
      server.on('GET', _hub, hubBody([hubRow('netbox', description: long)]));

      await pump(tester, width: 1000);
      expect(tester.widget<Text>(find.text(long)).maxLines, 2);

      await tester.tap(find.text('netbox'));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(inDetail(find.text(long))).maxLines, isNull);
    });

    testWidgets('pull to refresh loads again and keeps the rows', (
      tester,
    ) async {
      await pump(tester);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', _hub), hasLength(2));
      expect(find.text('netbox'), findsOneWidget);
    });

    testWidgets('tells the user when a refresh fails', (tester) async {
      await pump(tester);
      server.on('GET', _hub, {'detail': 'boom'}, status: 500);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh plugins'), findsOneWidget);
      expect(find.text('netbox'), findsOneWidget);
    });
  });

  group('details', () {
    testWidgets('open as a bottom sheet on a phone-width screen', (
      tester,
    ) async {
      await pump(tester, width: 400);

      await tester.tap(find.text('netbox'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(inDetail(find.text('Query NetBox')), findsOneWidget);
    });

    testWidgets('sit beside the list on a wide screen', (tester) async {
      await pump(tester, width: 1000);
      expect(find.byKey(const Key('plugin-detail')), findsNothing);

      await tester.tap(find.text('netbox'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(inDetail(find.text('Query NetBox')), findsOneWidget);
      final row = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'netbox'),
      );
      expect(row.selected, isTrue);
    });

    testWidgets('close when the plugin disappears from a reload', (
      tester,
    ) async {
      await pump(tester, width: 400);
      await tester.tap(find.text('netbox'));
      await tester.pumpAndSettle();
      server.on('GET', _hub, hubBody([hubRow('kanban')]));
      server.on('POST', '$_agent/netbox/disable', {'ok': true});

      await tester.tap(find.byKey(const Key('plugin-enabled')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
    });

    group('enabling', () {
      testWidgets('switches a plugin off and reflects the new state', (
        tester,
      ) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
        server
          ..on('POST', '$_agent/netbox/disable', {'ok': true})
          ..on('GET', _hub, hubBody([hubRow('netbox', status: 'disabled')]));

        await tester.tap(find.byKey(const Key('plugin-enabled')));
        await tester.pumpAndSettle();

        expect(
          server.requestsTo('POST', '$_agent/netbox/disable'),
          hasLength(1),
        );
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('plugin-enabled')))
              .value,
          isFalse,
        );
        expect(inDetail(find.text('Applies to new chats')), findsOneWidget);
      });

      testWidgets('shows the server\'s reason and keeps the switch', (
        tester,
      ) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
        server.on('POST', '$_agent/netbox/disable', {
          'detail': 'Plugin is locked.',
        }, status: 400);

        await tester.tap(find.byKey(const Key('plugin-enabled')));
        await tester.pumpAndSettle();

        expect(find.text('Plugin is locked.'), findsOneWidget);
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('plugin-enabled')))
              .value,
          isTrue,
        );
      });

      testWidgets('falls back to a plain message without a reason', (
        tester,
      ) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
        server.on('POST', '$_agent/netbox/disable', {}, status: 500);

        await tester.tap(find.byKey(const Key('plugin-enabled')));
        await tester.pumpAndSettle();

        expect(find.text('Could not update this plugin'), findsOneWidget);
      });
    });

    group('updating', () {
      Future<void> open(WidgetTester tester, {required bool canUpdate}) async {
        server.on(
          'GET',
          _hub,
          hubBody([hubRow('netbox', canUpdate: canUpdate)]),
        );
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
      }

      testWidgets('is only offered when the server can update', (tester) async {
        await open(tester, canUpdate: false);
        expect(find.byKey(const Key('plugin-update')), findsNothing);
      });

      testWidgets('says the plugin was updated', (tester) async {
        await open(tester, canUpdate: true);
        server.on('POST', '$_agent/netbox/update', {'ok': true, 'sha': 'abc'});

        await tester.tap(find.byKey(const Key('plugin-update')));
        await tester.pumpAndSettle();

        expect(find.text('Updated netbox'), findsOneWidget);
        expect(server.requestsTo('GET', _hub), hasLength(2));
      });

      testWidgets('says when there was nothing to update', (tester) async {
        await open(tester, canUpdate: true);
        server.on('POST', '$_agent/netbox/update', {
          'ok': true,
          'unchanged': true,
        });

        await tester.tap(find.byKey(const Key('plugin-update')));
        await tester.pumpAndSettle();

        expect(find.text('Already up to date'), findsOneWidget);
      });

      testWidgets('shows the server\'s reason when it refuses', (tester) async {
        await open(tester, canUpdate: true);
        server.on('POST', '$_agent/netbox/update', {
          'detail': 'Not a git checkout.',
        }, status: 400);

        await tester.tap(find.byKey(const Key('plugin-update')));
        await tester.pumpAndSettle();

        expect(find.text('Not a git checkout.'), findsOneWidget);
      });
    });

    group('removing', () {
      testWidgets('is not offered for a plugin that cannot be removed', (
        tester,
      ) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('kanban'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('plugin-remove')), findsNothing);
      });

      testWidgets('asks first, and does nothing when cancelled', (
        tester,
      ) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('plugin-remove')));
        await tester.pumpAndSettle();
        expect(find.text('Remove netbox?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(server.requestsTo('DELETE', '$_agent/netbox'), isEmpty);
        expect(find.text('netbox'), findsWidgets);
      });

      testWidgets('deletes after confirmation and closes the details', (
        tester,
      ) async {
        await pump(tester, width: 400);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
        server
          ..on('DELETE', '$_agent/netbox', {'ok': true})
          ..on('GET', _hub, hubBody([hubRow('kanban')]));

        await tester.tap(find.byKey(const Key('plugin-remove')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Remove'));
        await tester.pumpAndSettle();

        expect(server.requestsTo('DELETE', '$_agent/netbox'), hasLength(1));
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('netbox'), findsNothing);
      });

      testWidgets('keeps the plugin and says why when refused', (tester) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
        server.on('DELETE', '$_agent/netbox', {
          'detail': 'In use.',
        }, status: 400);

        await tester.tap(find.byKey(const Key('plugin-remove')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Remove'));
        await tester.pumpAndSettle();

        expect(find.text('In use.'), findsOneWidget);
        expect(find.text('netbox'), findsWidgets);
      });
    });

    group('hiding', () {
      testWidgets('sends the flag and reflects the new state', (tester) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
        server
          ..on('POST', '/api/dashboard/plugins/netbox/visibility', {'ok': true})
          ..on('GET', _hub, hubBody([hubRow('netbox', hidden: true)]));

        await tester.tap(find.byKey(const Key('plugin-hidden')));
        await tester.pumpAndSettle();

        final request = server
            .requestsTo('POST', '/api/dashboard/plugins/netbox/visibility')
            .single;
        expect(jsonBody(request), {'hidden': true});
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('plugin-hidden')))
              .value,
          isTrue,
        );
        expect(
          inDetail(find.text('Only affects the web dashboard')),
          findsOneWidget,
        );
      });

      testWidgets('leaves the switch alone when the call fails', (
        tester,
      ) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();
        server.on(
          'POST',
          '/api/dashboard/plugins/netbox/visibility',
          {},
          status: 500,
        );

        await tester.tap(find.byKey(const Key('plugin-hidden')));
        await tester.pumpAndSettle();

        expect(find.text('Could not update this plugin'), findsOneWidget);
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('plugin-hidden')))
              .value,
          isFalse,
        );
      });
    });

    group('login', () {
      final copied = <String>[];

      setUp(() {
        copied.clear();
        TestWidgetsFlutterBinding.ensureInitialized();
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

      testWidgets('shows the command and copies only that', (tester) async {
        server.on(
          'GET',
          _hub,
          hubBody([
            hubRow(
              'netbox',
              authRequired: true,
              authCommand: 'hermes auth netbox',
            ),
          ]),
        );
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();

        expect(inDetail(find.text('hermes auth netbox')), findsOneWidget);
        expect(inDetail(find.text('Run this on the server.')), findsOneWidget);
        await tester.tap(find.byKey(const Key('plugin-copy-login')));
        await tester.pumpAndSettle();

        expect(copied, ['hermes auth netbox']);
        expect(find.text('Copied'), findsOneWidget);
      });

      testWidgets('has no copy button without a command', (tester) async {
        server.on('GET', _hub, hubBody([hubRow('netbox', authRequired: true)]));
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();

        expect(inDetail(find.text('Needs login')), findsOneWidget);
        expect(find.byKey(const Key('plugin-copy-login')), findsNothing);
      });

      testWidgets('is absent when no login is needed', (tester) async {
        await pump(tester, width: 1000);
        await tester.tap(find.text('netbox'));
        await tester.pumpAndSettle();

        expect(inDetail(find.text('Needs login')), findsNothing);
      });
    });
  });

  group('telemetry', () {
    testWidgets('logs a change through the app\'s event logger', (
      tester,
    ) async {
      final events = <String>[];
      tester.view
        ..physicalSize = const Size(1000, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server.on('POST', '$_agent/netbox/disable', {'ok': true});

      await tester.pumpWidget(
        Provider<AppEventLogger>.value(
          value: (name, [attributes = const {}]) => events.add(name),
          child: MaterialApp(
            home: PluginsScreen(
              repository: HermesPluginManagerRepository(server.client().raw),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('netbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plugin-enabled')));
      await tester.pumpAndSettle();

      expect(events, ['plugins.disable.ok']);
    });
  });
}
