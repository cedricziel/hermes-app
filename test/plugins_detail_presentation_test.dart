import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/plugins/catalog_tab.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/installed_tab.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';

import 'hermes_plugin_manager_repository_test.dart'
    show catalogBody, catalogRow, hubBody, hubRow;
import 'support/fake_hermes_server.dart';

const _hub = '/api/dashboard/plugins/hub';
const _catalog = '/api/dashboard/plugins/catalog';
const _install = '/api/dashboard/agent-plugins/install';
const _disable = '/api/dashboard/agent-plugins/netbox/disable';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', _hub, hubBody([hubRow('netbox')]))
      ..on('GET', _catalog, catalogBody([catalogRow('catalog-plugin')]));
  });

  Future<void> openDetails(
    WidgetTester tester, {
    required bool catalog,
    TargetPlatform platform = TargetPlatform.macOS,
    double width = 700,
  }) async {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: platform),
        home: PluginsScreen(
          repository: HermesPluginManagerRepository(server.client().raw),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (catalog) {
      await tester.tap(
        find.descendant(
          of: find.byType(
            platform == TargetPlatform.macOS ? MacToolbarTabs : AdaptiveTabBar,
          ),
          matching: find.text('Catalog'),
        ),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.byKey(
        ValueKey(catalog ? 'catalog-row-catalog-plugin' : 'plugin-row-netbox'),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final catalog in [false, true]) {
    final label = catalog ? 'catalog' : 'installed';
    final detail = find.byKey(
      Key(catalog ? 'catalog-detail' : 'plugin-detail'),
    );

    testWidgets(
      'Mac $label details use a dialog and clear selection on dismissal',
      (tester) async {
        await openDetails(tester, catalog: catalog);

        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.ancestor(of: detail, matching: find.byType(Dialog)),
          findsOneWidget,
        );
        expect(tester.getCenter(find.byType(Dialog)).dy, closeTo(450, 1));
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();

        expect(detail, findsNothing);
        expect(find.byType(PluginsScreen), findsOneWidget);
        if (catalog) {
          expect(
            tester
                .widget<CatalogTab>(find.byType(CatalogTab))
                .controller
                .selectedName,
            isNull,
          );
        } else {
          expect(
            tester
                .widget<InstalledTab>(find.byType(InstalledTab))
                .controller
                .selectedName,
            isNull,
          );
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('wide Mac $label details remain beside the list', (
      tester,
    ) async {
      await openDetails(tester, catalog: catalog, width: 1000);

      expect(detail, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'Mac $label details close when a reload removes the selection',
      (tester) async {
        await openDetails(tester, catalog: catalog);

        if (catalog) {
          server.on('GET', _catalog, catalogBody([]));
          final controller = tester
              .widget<CatalogTab>(find.byType(CatalogTab))
              .controller;
          await tester.runAsync(controller.refresh);
        } else {
          server.on('GET', _hub, hubBody([]));
          final controller = tester
              .widget<InstalledTab>(find.byType(InstalledTab))
              .controller;
          await tester.runAsync(controller.refresh);
        }
        await tester.pumpAndSettle();

        expect(detail, findsNothing);
        expect(find.byType(PluginsScreen), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets(
        '$platform $label details preserve the mobile drag-handle sheet',
        (tester) async {
          await openDetails(
            tester,
            catalog: catalog,
            platform: platform,
            width: 390,
          );

          expect(detail, findsOneWidget);
          expect(find.byType(Dialog), findsNothing);
          expect(
            tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
            isTrue,
          );
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  testWidgets(
    'Mac catalog install remains busy and reports after detail dismissal',
    (tester) async {
      final held = Completer<FakeResponse>();
      server.onRequest('POST', _install, (_) => held.future);
      await openDetails(tester, catalog: true);
      final button = find.byKey(const Key('catalog-detail-install'));

      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tapAt(const Offset(8, 8));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('catalog-detail')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byKey(const Key('catalog-install-catalog-plugin')),
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      held.complete((
        status: 200,
        body: {'ok': true, 'plugin_name': 'catalog-plugin'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Installed catalog-plugin'), findsOneWidget);
      expect(find.byType(PluginsScreen), findsOneWidget);
      expect(server.requestsTo('POST', _install), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'Mac installed actions stay disabled until a held change finishes',
    (tester) async {
      final held = Completer<FakeResponse>();
      server.onRequest('POST', _disable, (_) => held.future);
      await openDetails(tester, catalog: false);
      final enabled = find.descendant(
        of: find.byKey(const Key('plugin-enabled')),
        matching: find.byType(Switch),
      );

      await tester.tap(enabled);
      await tester.pump();
      expect(tester.widget<Switch>(enabled).onChanged, isNull);
      server.on('GET', _hub, hubBody([hubRow('netbox', status: 'disabled')]));
      held.complete((status: 200, body: {'ok': true}));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(enabled).value, isFalse);
      expect(tester.widget<Switch>(enabled).onChanged, isNotNull);
      expect(server.requestsTo('POST', _disable), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
