import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'running'),
        ),
      )
      ..on('GET', '/api/plugins/kanban/assignees', {'assignees': <String>[]});
  });

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required TargetPlatform platform,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: platform),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showKanbanTask(
                  context,
                  repository: KanbanRepository(server.client()),
                  taskId: 't1',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  const grabber = Key('kanbanTaskGrabber');
  const sheet = Key('kanbanTaskSheet');

  double sheetHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(sheet)).height;

  testWidgets('iPhone: a sheet with a grabber that opens at a medium detent', (
    tester,
  ) async {
    await open(
      tester,
      size: const Size(393, 852),
      platform: TargetPlatform.iOS,
    );

    expect(tester.getSize(find.byKey(grabber)), const Size(36, 5));
    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(sheetHeight(tester), closeTo(852 * 0.5, 2));

    await tester.fling(
      find.byKey(grabber),
      const Offset(0, -600),
      1500,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(sheetHeight(tester), greaterThan(852 * 0.9));

    await tester.fling(
      find.byKey(grabber),
      const Offset(0, 900),
      1500,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(sheet), findsNothing);
  });

  for (final (name, size, platform) in [
    ('iPad', const Size(834, 1194), TargetPlatform.iOS),
    ('Mac', const Size(1280, 800), TargetPlatform.macOS),
  ]) {
    testWidgets('$name: a centred form sheet with the iOS corner radius', (
      tester,
    ) async {
      await open(tester, size: size, platform: platform);

      final box = tester.getRect(find.byKey(sheet));
      expect(box.width, inInclusiveRange(540, 700));
      expect(box.center.dx, closeTo(size.width / 2, 1));
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(
        dialog.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      );
      expect(find.byKey(grabber), findsNothing);
      expect(find.text('Migrate webhooks'), findsOneWidget);
    });
  }

  testWidgets('Android keeps the Material sheet', (tester) async {
    await open(
      tester,
      size: const Size(412, 915),
      platform: TargetPlatform.android,
    );

    expect(find.byKey(grabber), findsNothing);
    expect(find.byKey(sheet), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Migrate webhooks'), findsOneWidget);
  });

  testWidgets('Android keeps the Material dialog on a wide screen', (
    tester,
  ) async {
    await open(
      tester,
      size: const Size(1280, 800),
      platform: TargetPlatform.android,
    );

    expect(find.byKey(sheet), findsNothing);
    expect(find.byType(Dialog), findsOneWidget);
  });
}
