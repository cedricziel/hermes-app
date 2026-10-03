import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';

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

  Future<void> pumpScreen(WidgetTester tester, TargetPlatform platform) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: PluginsScreen(
          repository: HermesPluginManagerRepository(server.client().raw),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('swiping a plugin left removes it after confirming', (
    tester,
  ) async {
    server.on('DELETE', '$_agent/netbox', {'ok': true});
    await pumpScreen(tester, TargetPlatform.iOS);

    await tester.drag(find.text('netbox'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(server.requestsTo('DELETE', '$_agent/netbox'), isEmpty);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Remove'));
    await tester.pumpAndSettle();

    expect(server.requestsTo('DELETE', '$_agent/netbox'), hasLength(1));
  });

  testWidgets('a long press offers to disable an enabled plugin', (
    tester,
  ) async {
    server.on('POST', '$_agent/netbox/disable', {'ok': true});
    await pumpScreen(tester, TargetPlatform.iOS);

    await tester.longPress(find.text('netbox'));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();

    expect(server.requestsTo('POST', '$_agent/netbox/disable'), hasLength(1));
  });

  testWidgets('a plugin that cannot be removed has no Remove action', (
    tester,
  ) async {
    await pumpScreen(tester, TargetPlatform.iOS);

    await tester.longPress(find.text('kanban'));
    await tester.pumpAndSettle();

    expect(find.text('Remove'), findsNothing);
    expect(find.text('Disable'), findsOneWidget);
  });

  testWidgets('Android rows have no swipe actions', (tester) async {
    await pumpScreen(tester, TargetPlatform.android);

    expect(find.byType(Slidable), findsNothing);
  });
}
