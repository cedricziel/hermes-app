import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/widgets/update_confirm_dialog.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

void main() {
  bool? answer;
  var asked = false;

  Future<void> open(WidgetTester tester, TargetPlatform platform) async {
    answer = null;
    asked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: platform),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  asked = true;
                  answer = await showAppDialog<bool>(
                    context: context,
                    builder: (_) => const UpdateConfirmDialog(
                      title: 'Update Hermes now?',
                      lines: [
                        'Chats in this app keep running.',
                        'Second line.',
                      ],
                      confirmLabel: 'Update',
                      cancelLabel: 'Cancel',
                    ),
                  );
                },
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(asked, isTrue);
  }

  group('on the Mac', () {
    testWidgets('it is an alert, never a sheet', (tester) async {
      await open(tester, TargetPlatform.macOS);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Update Hermes now?'), findsOneWidget);
    });

    testWidgets('Cancel comes first and is the default, Update is not', (
      tester,
    ) async {
      await open(tester, TargetPlatform.macOS);
      final actions = tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .toList();
      expect(actions, hasLength(2));
      expect((actions[0].child as Text).data, 'Cancel');
      expect(actions[0].isDefaultAction, isTrue);
      expect((actions[1].child as Text).data, 'Update');
      expect(actions[1].isDefaultAction, isFalse);
      expect(
        tester.getTopLeft(find.text('Cancel')).dx,
        lessThan(tester.getTopLeft(find.text('Update')).dx),
        reason: 'Cancel is left of Update in the two-button alert',
      );
    });

    testWidgets('Return does not update', (tester) async {
      await open(tester, TargetPlatform.macOS);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(answer, isNot(isTrue));
    });

    testWidgets('Escape cancels', (tester) async {
      await open(tester, TargetPlatform.macOS);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(answer, isNot(isTrue));
    });

    testWidgets('Update answers true, Cancel answers false', (tester) async {
      await open(tester, TargetPlatform.macOS);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
      await open(tester, TargetPlatform.macOS);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });
  });

  testWidgets('on iOS Cancel is the default action too', (tester) async {
    await open(tester, TargetPlatform.iOS);
    final actions = tester
        .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
        .toList();
    expect((actions[0].child as Text).data, 'Cancel');
    expect(actions[0].isDefaultAction, isTrue);
    expect(actions[1].isDefaultAction, isFalse);
  });

  testWidgets('on Android: two text buttons, Cancel first, nothing filled', (
    tester,
  ) async {
    await open(tester, TargetPlatform.android);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    final buttons = tester
        .widgetList<TextButton>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
        )
        .toList();
    expect(buttons, hasLength(2));
    expect((buttons[0].child as Text).data, 'Cancel');
    expect((buttons[1].child as Text).data, 'Update');
    expect(
      tester.getTopLeft(find.text('Cancel')).dx,
      lessThan(tester.getTopLeft(find.text('Update')).dx),
    );
  });

  testWidgets('on Material dark the dialog surface is not the scaffold black', (
    tester,
  ) async {
    answer = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesDarkTheme(platform: TargetPlatform.android),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppDialog<bool>(
                context: context,
                builder: (_) => const UpdateConfirmDialog(
                  title: 'T',
                  lines: ['L'],
                  confirmLabel: 'Update',
                  cancelLabel: 'Cancel',
                ),
              ),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    final scaffold = Theme.of(tester.element(find.byType(AlertDialog)))
        .scaffoldBackgroundColor;
    expect(material.color, isNot(scaffold));
    expect(material.color, HermesColors.zinc800);
  });
}
