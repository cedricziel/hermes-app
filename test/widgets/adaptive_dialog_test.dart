import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

Future<void> _open(
  WidgetTester tester,
  TargetPlatform platform, {
  bool destructive = false,
  void Function(bool)? onAnswer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final answer = await showConfirmDialog(
              context,
              title: 'Delete this chat?',
              message: 'It goes for good.',
              confirmLabel: 'Delete',
              destructive: destructive,
            );
            onAnswer?.call(answer);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('confirm is a Cupertino alert on $platform', (tester) async {
      await _open(tester, platform, destructive: true);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final delete = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Delete'),
      );
      expect(delete.isDestructiveAction, isTrue);
    });
  }

  testWidgets('confirm stays a Material alert on Android', (tester) async {
    await _open(tester, TargetPlatform.android);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('answers true on confirm and false on cancel', (tester) async {
    final answers = <bool>[];
    await _open(tester, TargetPlatform.iOS, onAnswer: answers.add);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answers, [true, false]);
  });
}
