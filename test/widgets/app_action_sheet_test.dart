import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/app_action_sheet.dart';

void main() {
  Future<void> open(WidgetTester tester, List<String?> answers) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(
              await showAppActionSheet<String>(
                context: context,
                title: 'Nightly',
                entries: const [
                  AppActionSheetEntry('Rename', 'rename'),
                  AppActionSheetEntry('Delete', 'delete', destructive: true),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a destructive entry answers its value and is drawn destructive',
    (tester) async {
      final answers = <String?>[];
      await open(tester, answers);
      final delete = tester.widget<CupertinoActionSheetAction>(
        find.widgetWithText(CupertinoActionSheetAction, 'Delete'),
      );
      expect(delete.isDestructiveAction, isTrue);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(answers, ['delete']);
    },
  );

  testWidgets('Cancel answers null', (tester) async {
    final answers = <String?>[];
    await open(tester, answers);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answers, [null]);
  });
}
