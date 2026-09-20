import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';

import 'hermes_plugin_manager_repository_test.dart'
    show catalogBody, catalogRow, hubBody, hubRow;
import 'support/fake_hermes_server.dart';

const catalogPath = '/api/dashboard/plugins/catalog';
const _hub = '/api/dashboard/plugins/hub';

/// The Plugins screen's Catalog tab against a fake dashboard.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', _hub, hubBody([hubRow('netbox')]))
      ..on(
        'GET',
        catalogPath,
        catalogBody([
          catalogRow(
            'hermes-plugin-chrome-profiles',
            tier: 'official',
            maintainer: 'Acme',
            description: 'Switch Chrome profiles from the agent',
          ),
          catalogRow('hermes-plugin-netbox', installed: true),
          catalogRow(
            'hermes-snapcompact',
            installed: true,
            updateAvailable: true,
          ),
        ]),
      );
  });

  final launched = <Uri>[];
  final events = <(String, Map<String, Object>)>[];

  Future<void> pump(WidgetTester tester, {double width = 400}) async {
    launched.clear();
    events.clear();
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PluginsScreen(
          repository: HermesPluginManagerRepository(server.client().raw),
          events: (name, [attributes = const {}]) =>
              events.add((name, attributes)),
          openLink: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCatalog(WidgetTester tester, {double width = 400}) async {
    await pump(tester, width: width);
    await tester.tap(find.widgetWithText(Tab, 'Catalog'));
    await tester.pumpAndSettle();
  }

  group('tabs', () {
    testWidgets('open on Installed without asking for the catalog', (
      tester,
    ) async {
      await pump(tester);

      expect(find.widgetWithText(Tab, 'Installed'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Catalog'), findsOneWidget);
      expect(find.text('netbox'), findsOneWidget);
      expect(server.requestsTo('GET', catalogPath), isEmpty);
    });

    testWidgets('ask for the catalog when it is first opened, and once', (
      tester,
    ) async {
      await openCatalog(tester);
      expect(server.requestsTo('GET', catalogPath), hasLength(1));

      await tester.tap(find.widgetWithText(Tab, 'Installed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Catalog'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', catalogPath), hasLength(1));
    });

    testWidgets('keep the search text across a switch', (tester) async {
      await openCatalog(tester);
      await tester.enterText(find.byKey(const Key('catalog-search')), 'snap');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Installed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Catalog'));
      await tester.pumpAndSettle();

      expect(find.text('snap'), findsOneWidget);
      expect(find.text('hermes-snapcompact'), findsOneWidget);
      expect(find.text('hermes-plugin-chrome-profiles'), findsNothing);
    });
  });

  group('list', () {
    testWidgets('shows a spinner, then the entries in the server\'s order', (
      tester,
    ) async {
      final gate = Completer<void>();
      server.onRequest('GET', catalogPath, (_) async {
        await gate.future;
        return (
          status: 200,
          body: catalogBody([catalogRow('zeta'), catalogRow('alpha')]),
        );
      });
      await pump(tester);
      await tester.tap(find.widgetWithText(Tab, 'Catalog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.getTopLeft(find.text('zeta')).dy,
        lessThan(tester.getTopLeft(find.text('alpha')).dy),
      );
    });

    testWidgets('says so when the catalog is empty', (tester) async {
      server.on('GET', catalogPath, catalogBody([]));

      await openCatalog(tester);

      expect(find.text('The catalog is empty'), findsOneWidget);
    });

    testWidgets('offers Retry after a failed load', (tester) async {
      server.on('GET', catalogPath, {'detail': 'boom'}, status: 500);
      await openCatalog(tester);
      expect(find.text('Could not load the catalog'), findsOneWidget);

      server.on('GET', catalogPath, catalogBody([catalogRow('a-plugin')]));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('a-plugin'), findsOneWidget);
    });

    testWidgets('says the catalog is unavailable on an old server', (
      tester,
    ) async {
      server.on('GET', catalogPath, {'detail': 'Not Found'}, status: 404);

      await openCatalog(tester);

      expect(
        find.text('The catalog is not available on this server'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('shows what each entry is and where it stands', (tester) async {
      await openCatalog(tester);

      final chrome = find.widgetWithText(
        ListTile,
        'hermes-plugin-chrome-profiles',
      );
      expect(
        find.descendant(of: chrome, matching: find.text('Acme')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: chrome,
          matching: find.text('Switch Chrome profiles from the agent'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chrome, matching: find.text('a3f9c21')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chrome, matching: find.text('Official')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
        findsOneWidget,
      );
      expect(find.text('Official'), findsOneWidget);
    });

    testWidgets('marks installed entries and those with an update', (
      tester,
    ) async {
      await openCatalog(tester);

      expect(find.text('Installed'), findsNWidgets(3));
      expect(find.text('Update available'), findsOneWidget);
      expect(
        find.byKey(const Key('catalog-install-hermes-plugin-netbox')),
        findsNothing,
      );
    });

    testWidgets('cuts a long description to two lines', (tester) async {
      final long = List.filled(40, 'word').join(' ');
      server.on(
        'GET',
        catalogPath,
        catalogBody([catalogRow('x', description: long)]),
      );

      await openCatalog(tester);

      expect(tester.widget<Text>(find.text(long)).maxLines, 2);
    });

    testWidgets('pull to refresh loads again and keeps the rows', (
      tester,
    ) async {
      await openCatalog(tester);

      await tester.fling(
        find.byKey(const Key('catalog-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', catalogPath), hasLength(2));
      expect(find.text('hermes-snapcompact'), findsOneWidget);
    });

    testWidgets('tells the user when a refresh fails', (tester) async {
      await openCatalog(tester);
      server.on('GET', catalogPath, {'detail': 'boom'}, status: 500);

      await tester.fling(
        find.byKey(const Key('catalog-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh the catalog'), findsOneWidget);
      expect(find.text('hermes-snapcompact'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('narrows the rows as the user types', (tester) async {
      await openCatalog(tester);

      await tester.enterText(find.byKey(const Key('catalog-search')), 'NETBOX');
      await tester.pumpAndSettle();

      expect(find.text('hermes-plugin-netbox'), findsOneWidget);
      expect(find.text('hermes-snapcompact'), findsNothing);
    });

    testWidgets('says when nothing matches', (tester) async {
      await openCatalog(tester);

      await tester.enterText(find.byKey(const Key('catalog-search')), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No plugins match'), findsOneWidget);
    });
  });

  group('details', () {
    final rich = catalogRow(
      'hermes-plugin-netbox',
      tier: 'official',
      maintainer: 'Andrew',
      description: 'NetBox change management with a reviewed diff.',
      tools: ['netbox_query', 'netbox_apply'],
      middleware: ['audit'],
      env: ['NETBOX_URL', 'NETBOX_TOKEN'],
      platforms: ['linux', 'macos'],
      requiresHermes: '>=0.20',
      docsUrl: 'https://example.com/netbox',
    );

    Finder inDetail(Finder finder) => find.descendant(
      of: find.byKey(const Key('catalog-detail')),
      matching: finder,
    );

    Future<void> openRich(WidgetTester tester, {double width = 400}) async {
      server.on('GET', catalogPath, catalogBody([rich, catalogRow('other')]));
      await openCatalog(tester, width: width);
      await tester.tap(find.text('hermes-plugin-netbox'));
      await tester.pumpAndSettle();
    }

    testWidgets('open as a bottom sheet on a phone-width screen', (
      tester,
    ) async {
      await openRich(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        inDetail(find.text('NetBox change management with a reviewed diff.')),
        findsOneWidget,
      );
    });

    testWidgets('sit beside the list on a wide screen', (tester) async {
      await openRich(tester, width: 1000);

      expect(find.byType(BottomSheet), findsNothing);
      expect(inDetail(find.text('Andrew')), findsOneWidget);
      final row = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'hermes-plugin-netbox'),
      );
      expect(row.selected, isTrue);
    });

    testWidgets('show what the entry needs and provides', (tester) async {
      await openRich(tester);

      expect(inDetail(find.text('Official')), findsOneWidget);
      expect(inDetail(find.text('a3f9c21')), findsOneWidget);
      expect(inDetail(find.text('Requires Hermes >=0.20')), findsOneWidget);
      expect(inDetail(find.text('Platforms: linux, macos')), findsOneWidget);
      expect(inDetail(find.text('Tools')), findsOneWidget);
      expect(inDetail(find.text('netbox_query')), findsOneWidget);
      expect(inDetail(find.text('netbox_apply')), findsOneWidget);
      expect(inDetail(find.text('Middleware')), findsOneWidget);
      expect(inDetail(find.text('audit')), findsOneWidget);
      expect(inDetail(find.text('Environment variables')), findsOneWidget);
      expect(inDetail(find.text('NETBOX_TOKEN')), findsOneWidget);
    });

    testWidgets('leave out groups the entry does not declare', (tester) async {
      await openRich(tester);

      expect(inDetail(find.text('Hooks')), findsNothing);
    });

    testWidgets('leave out what an entry does not name', (tester) async {
      server.on('GET', catalogPath, catalogBody([catalogRow('plain')]));
      await openCatalog(tester);
      await tester.tap(find.text('plain'));
      await tester.pumpAndSettle();

      expect(inDetail(find.textContaining('Requires Hermes')), findsNothing);
      expect(inDetail(find.textContaining('Platforms')), findsNothing);
      expect(find.byKey(const Key('catalog-docs-link')), findsNothing);
    });

    testWidgets('open the docs in the browser for an https address', (
      tester,
    ) async {
      await openRich(tester);

      await tester.tap(find.byKey(const Key('catalog-docs-link')));
      await tester.pumpAndSettle();

      expect(launched, [Uri.parse('https://example.com/netbox')]);
    });

    testWidgets('offer no link for another scheme', (tester) async {
      server.on(
        'GET',
        catalogPath,
        catalogBody([
          catalogRow('odd', docsUrl: 'javascript:alert(1)'),
          catalogRow('local', docsUrl: 'file:///etc/passwd'),
        ]),
      );
      await openCatalog(tester);

      await tester.tap(find.text('odd'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog-docs-link')), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('local'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog-docs-link')), findsNothing);
    });

    testWidgets('empty the pane when a reload drops the entry', (tester) async {
      await openRich(tester, width: 1000);
      server.on('GET', catalogPath, catalogBody([catalogRow('other')]));

      await tester.fling(
        find.byKey(const Key('catalog-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catalog-detail')), findsNothing);
      expect(find.text('Select a plugin'), findsOneWidget);
    });
  });

  group('installing', () {
    const install = '/api/dashboard/agent-plugins/install';

    Future<void> openSheet(WidgetTester tester, String name) async {
      await openCatalog(tester);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    Object? lastBody() => jsonBody(server.requestsTo('POST', install).last);

    testWidgets('installs from a row with the catalog name', (tester) async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'chrome'});
      await openCatalog(tester);

      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
      );
      await tester.pumpAndSettle();

      expect(lastBody(), {
        'identifier': '',
        'catalog_name': 'hermes-plugin-chrome-profiles',
        'enable': true,
        'force': false,
      });
    });

    testWidgets('installs from the details, with enabling on by default', (
      tester,
    ) async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'chrome'});
      await openSheet(tester, 'hermes-plugin-chrome-profiles');
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('catalog-enable-switch')),
            )
            .value,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('catalog-detail-install')));
      await tester.pumpAndSettle();

      expect((lastBody()! as Map)['enable'], isTrue);
    });

    testWidgets('does not enable when the switch is off', (tester) async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'chrome'});
      await openSheet(tester, 'hermes-plugin-chrome-profiles');

      await tester.tap(find.byKey(const Key('catalog-enable-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-detail-install')));
      await tester.pumpAndSettle();

      expect((lastBody()! as Map)['enable'], isFalse);
    });

    testWidgets('offers no install for an installed entry', (tester) async {
      await openSheet(tester, 'hermes-plugin-netbox');

      expect(find.byKey(const Key('catalog-detail-install')), findsNothing);
      expect(find.byKey(const Key('catalog-enable-switch')), findsNothing);
    });

    testWidgets('shows progress and ignores a second tap', (tester) async {
      final gate = Completer<void>();
      server.onRequest('POST', install, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'plugin_name': 'chrome'});
      });
      await openCatalog(tester);
      final button = find.byKey(
        const Key('catalog-install-hermes-plugin-chrome-profiles'),
      );

      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(server.requestsTo('POST', install), hasLength(1));
    });

    testWidgets('says what was installed and reloads both lists', (
      tester,
    ) async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'chrome'});
      await openCatalog(tester);

      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Installed chrome'), findsOneWidget);
      expect(server.requestsTo('GET', catalogPath), hasLength(2));
      expect(server.requestsTo('GET', _hub), hasLength(2));
    });

    testWidgets('shows the server\'s warnings', (tester) async {
      server.on('POST', install, {
        'ok': true,
        'plugin_name': 'chrome',
        'warnings': ['Insecure URL scheme; prefer https:// or git@.'],
      });
      await openCatalog(tester);

      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Insecure URL scheme; prefer https:// or git@.'),
        findsOneWidget,
      );
    });

    testWidgets('lists the variables the user still has to set', (
      tester,
    ) async {
      server.on('POST', install, {
        'ok': true,
        'plugin_name': 'chrome',
        'missing_env': ['NETBOX_URL', 'NETBOX_TOKEN'],
      });
      await openCatalog(tester);

      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set these on the server'), findsOneWidget);
      expect(find.text('NETBOX_URL'), findsOneWidget);
      expect(find.text('NETBOX_TOKEN'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows the server\'s reason and changes nothing when refused', (
      tester,
    ) async {
      server.on('POST', install, {
        'detail': "'x' is on the removed list.",
      }, status: 400);
      await openCatalog(tester);

      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
      );
      await tester.pumpAndSettle();

      expect(find.text("'x' is on the removed list."), findsOneWidget);
      expect(server.requestsTo('GET', catalogPath), hasLength(1));
      expect(server.requestsTo('GET', _hub), hasLength(1));
    });

    testWidgets('does not call a timeout a failure', (tester) async {
      server.onRequest(
        'POST',
        install,
        (request) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 30),
          requestOptions: request,
        ),
      );
      await openCatalog(tester);

      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The server is still installing. Pull the list down in a moment to check.',
        ),
        findsOneWidget,
      );
      expect(find.text('Could not install this plugin'), findsNothing);
      expect(server.requestsTo('GET', catalogPath), hasLength(2));
      expect(server.requestsTo('GET', _hub), hasLength(2));
    });

    testWidgets('says so when the server cannot be reached', (tester) async {
      server.onRequest(
        'POST',
        install,
        (_) => throw const SocketException('no route to host'),
      );
      await openCatalog(tester);

      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-chrome-profiles')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not install this plugin'), findsOneWidget);
    });
  });

  group('installing from a Git URL', () {
    const install = '/api/dashboard/agent-plugins/install';
    const token = 'https://user:secret-token@example.com/x.git';

    Future<void> openDialog(WidgetTester tester) async {
      await openCatalog(tester);
      await tester.tap(find.byKey(const Key('catalog-git-install')));
      await tester.pumpAndSettle();
    }

    Future<void> fill(
      WidgetTester tester,
      String text, {
      bool trust = true,
    }) async {
      await tester.enterText(find.byKey(const Key('git-url-field')), text);
      if (trust) await tester.tap(find.byKey(const Key('git-trust-checkbox')));
      await tester.pumpAndSettle();
    }

    FilledButton installButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const Key('git-install')));

    Map<String, Object?> lastBody() =>
        jsonBody(server.requestsTo('POST', install).last)!
            as Map<String, Object?>;

    testWidgets('opens with the warning showing and Install disabled', (
      tester,
    ) async {
      await openDialog(tester);

      expect(find.text('Install from Git URL'), findsOneWidget);
      expect(
        find.text(
          'Unreviewed code. This plugin is not from the Hermes catalog. It runs on your server with full access.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('git-trust-checkbox')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('git-enable-switch')))
            .value,
        isTrue,
      );
      expect(find.byKey(const Key('git-force-switch')), findsNothing);
      expect(installButton(tester).onPressed, isNull);
    });

    testWidgets('needs both a source and the tick', (tester) async {
      await openDialog(tester);

      await fill(tester, 'someone/hermes-cool-plugin', trust: false);
      expect(installButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('git-url-field')), '   ');
      await tester.tap(find.byKey(const Key('git-trust-checkbox')));
      await tester.pumpAndSettle();
      expect(installButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('git-url-field')),
        'someone/hermes-cool-plugin',
      );
      await tester.pumpAndSettle();
      expect(installButton(tester).onPressed, isNotNull);
    });

    testWidgets('sends the trimmed source and no catalog name', (tester) async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'cool'});
      await openDialog(tester);
      await fill(tester, '  someone/hermes-cool-plugin  ');

      await tester.tap(find.byKey(const Key('git-install')));
      await tester.pumpAndSettle();

      expect(lastBody(), {
        'identifier': 'someone/hermes-cool-plugin',
        'enable': true,
        'force': false,
      });
      expect(find.text('Installed cool'), findsOneWidget);
      expect(find.text('Install from Git URL'), findsNothing);
    });

    testWidgets('sends force only after Advanced is opened and switched on', (
      tester,
    ) async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'cool'});
      await openDialog(tester);
      await fill(tester, 'someone/cool');
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('git-force-switch')));
      await tester.tap(find.byKey(const Key('git-enable-switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('git-install')));
      await tester.pumpAndSettle();

      expect(lastBody()['force'], isTrue);
      expect(lastBody()['enable'], isFalse);
    });

    testWidgets(
      'reports warnings, variables and refusals like a catalog install',
      (tester) async {
        server.on('POST', install, {
          'ok': true,
          'plugin_name': 'cool',
          'warnings': [
            'Custom (unreviewed) source — not from the Hermes catalog.',
          ],
          'missing_env': ['COOL_TOKEN'],
        });
        await openDialog(tester);
        await fill(tester, 'someone/cool');
        await tester.tap(find.byKey(const Key('git-install')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Custom (unreviewed) source — not from the Hermes catalog.',
          ),
          findsOneWidget,
        );
        expect(find.text('Set these on the server'), findsOneWidget);
        expect(find.text('COOL_TOKEN'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        server.on('POST', install, {'detail': 'Not a plugin.'}, status: 400);
        await tester.tap(find.byKey(const Key('catalog-git-install')));
        await tester.pumpAndSettle();
        await fill(tester, 'someone/other');
        await tester.tap(find.byKey(const Key('git-install')));
        await tester.pumpAndSettle();

        expect(find.text('Not a plugin.'), findsOneWidget);
        expect(find.text('Install from Git URL'), findsNothing);
      },
    );

    testWidgets('shows progress and cannot be dismissed while it runs', (
      tester,
    ) async {
      final gate = Completer<void>();
      server.onRequest('POST', install, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'plugin_name': 'cool'});
      });
      await openDialog(tester);
      await fill(tester, 'someone/cool');

      await tester.tap(find.byKey(const Key('git-install')));
      await tester.pump();

      expect(installButton(tester).onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('git-install')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(server.requestsTo('POST', install), hasLength(1));
    });

    testWidgets('cancel closes it without a request', (tester) async {
      await openDialog(tester);
      await fill(tester, 'someone/cool');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Install from Git URL'), findsNothing);
      expect(server.requestsTo('POST', install), isEmpty);
    });

    testWidgets('keeps the typed address out of events and messages', (
      tester,
    ) async {
      server.on('POST', install, {
        'detail': 'Could not fetch it.',
      }, status: 400);
      await openDialog(tester);
      await fill(tester, token);
      await tester.tap(find.byKey(const Key('git-install')));
      await tester.pumpAndSettle();

      expect(events.map((e) => e.$1), ['plugins.install_custom.error']);
      expect(events.single.$2, isEmpty);
      expect(find.textContaining('secret-token'), findsNothing);
    });
  });
}
