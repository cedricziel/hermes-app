import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
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
                  AppActionSheetEntry(label: 'Rename', value: 'rename'),
                  AppActionSheetEntry(
                    label: 'Delete',
                    value: 'delete',
                    destructive: true,
                  ),
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

  testWidgets('the sheet still builds after its opener is gone', (
    tester,
  ) async {
    final showOpener = ValueNotifier(true);
    final dark = ValueNotifier(false);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: dark,
        builder: (_, isDark, _) => MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            brightness: isDark ? Brightness.dark : Brightness.light,
          ),
          home: ValueListenableBuilder<bool>(
            valueListenable: showOpener,
            builder: (_, show, _) => show
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showAppActionSheet<String>(
                        context: context,
                        title: 'Nightly',
                        entries: const [
                          AppActionSheetEntry(label: 'Rename', value: 'rename'),
                        ],
                      ),
                      child: const Text('Open'),
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    showOpener.value = false;
    await tester.pump();
    dark.value = true;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
