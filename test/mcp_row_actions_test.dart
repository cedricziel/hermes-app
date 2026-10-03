import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'grafana', url: 'https://mcp.grafana.com/mcp'),
          mcpServerRow(name: 'filesystem', command: 'npx', enabled: false),
        ]),
      );
  });

  Future<void> pumpScreen(WidgetTester tester, TargetPlatform platform) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: McpServersScreen(
          repository: HermesMcpRepository(server.client().raw),
          profiles: HermesProfilesRepository(server.client().raw),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('swiping a server left removes it after confirming', (
    tester,
  ) async {
    server.on('DELETE', '/api/mcp/servers/grafana', {'ok': true});
    await pumpScreen(tester, TargetPlatform.iOS);

    await tester.drag(find.text('grafana'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(server.requestsTo('DELETE', '/api/mcp/servers/grafana'), isEmpty);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Remove'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('DELETE', '/api/mcp/servers/grafana'),
      hasLength(1),
    );
  });

  testWidgets('a long press offers to turn a server on or off', (tester) async {
    server.on('PUT', '/api/mcp/servers/grafana/enabled', {'ok': true});
    await pumpScreen(tester, TargetPlatform.iOS);

    await tester.longPress(find.text('grafana'));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('PUT', '/api/mcp/servers/grafana/enabled'),
      hasLength(1),
    );
  });

  testWidgets('a server that is off offers to turn it on', (tester) async {
    await pumpScreen(tester, TargetPlatform.iOS);

    await tester.longPress(find.text('filesystem'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('Android rows have no swipe actions', (tester) async {
    await pumpScreen(tester, TargetPlatform.android);

    expect(find.byType(Slidable), findsNothing);
  });
}
