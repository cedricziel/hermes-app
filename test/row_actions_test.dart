import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';

void main() {
  late List<String> done;

  setUp(() => done = []);

  Future<void> pumpRow(WidgetTester tester, TargetPlatform platform) =>
      tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: RowActions(
              title: 'Nightly',
              actions: [
                RowAction(
                  label: 'Turn off',
                  icon: Icons.pause,
                  onPressed: () => done.add('off'),
                ),
                RowAction(
                  label: 'Delete',
                  icon: Icons.delete,
                  destructive: true,
                  onPressed: () => done.add('delete'),
                ),
              ],
              child: const ListTile(title: Text('Nightly')),
            ),
          ),
        ),
      );

  testWidgets('iOS: a swipe reveals Delete', (tester) async {
    await pumpRow(tester, TargetPlatform.iOS);

    await tester.drag(find.text('Nightly'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(done, ['delete']);
    expect(find.text('Turn off'), findsNothing);
  });

  testWidgets('iOS: a long press lists every action in a sheet', (
    tester,
  ) async {
    await pumpRow(tester, TargetPlatform.iOS);

    await tester.longPress(find.text('Nightly'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();

    expect(done, ['off']);
  });

  testWidgets('iOS: VoiceOver can run every action', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRow(tester, TargetPlatform.iOS);

    final data = tester.getSemantics(find.text('Nightly')).getSemanticsData();
    final labels = [
      for (final id in data.customSemanticsActionIds!)
        CustomSemanticsAction.getAction(id)!.label,
    ];

    expect(labels, containsAll(['Turn off', 'Delete']));
    handle.dispose();
  });

  testWidgets('macOS: a right click opens a menu', (tester) async {
    await pumpRow(tester, TargetPlatform.macOS);

    final click = await tester.startGesture(
      tester.getCenter(find.text('Nightly')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await click.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(done, ['delete']);
    expect(find.byType(Slidable), findsNothing);
  });

  testWidgets('Android: the row is left alone', (tester) async {
    await pumpRow(tester, TargetPlatform.android);

    expect(find.byType(Slidable), findsNothing);
    await tester.longPress(find.text('Nightly'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });
}
