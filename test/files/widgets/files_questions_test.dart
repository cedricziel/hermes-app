import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/files_questions.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import 'files_widget_harness.dart';

/// A page with a button that asks [ask] and records the answer.
Widget _page(
  Future<bool> Function(BuildContext context) ask,
  void Function(bool answer) onAnswer,
) => Builder(
  builder: (context) => TextButton(
    onPressed: () async => onAnswer(await ask(context)),
    child: const Text('ask'),
  ),
);

void main() {
  group('size question', () {
    testWidgets('a phone gets a sheet: the sentence, Cancel, Download', (
      tester,
    ) async {
      bool? answer;
      await pumpFiles(
        tester,
        _page((c) => askDownloadLargeFile(c, 222298112), (a) => answer = a),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text('This file is 212 MB. Download it anyway?'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });

    testWidgets('Cancel on the sheet answers no', (tester) async {
      bool? answer;
      await pumpFiles(
        tester,
        _page((c) => askDownloadLargeFile(c, 222298112), (a) => answer = a),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('dismissing the sheet answers no', (tester) async {
      bool? answer;
      await pumpFiles(
        tester,
        _page((c) => askDownloadLargeFile(c, 222298112), (a) => answer = a),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('an iPad gets an alert with the sentence as its title', (
      tester,
    ) async {
      bool? answer;
      await pumpFiles(
        tester,
        _page((c) => askDownloadLargeFile(c, 222298112), (a) => answer = a),
        size: const Size(820, 1180),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(
        find.text('This file is 212 MB. Download it anyway?'),
        findsOneWidget,
      );
      final download = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Download'),
      );
      expect(download.isDefaultAction, isTrue);

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });

    testWidgets('a Mac gets an alert, never a sheet', (tester) async {
      await pumpFiles(
        tester,
        _page((c) => askDownloadLargeFile(c, 222298112), (_) {}),
        platform: TargetPlatform.macOS,
        size: const Size(1000, 800),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AppAlertDialog), findsOneWidget);
    });

    testWidgets('the sentence is German in German', (tester) async {
      await pumpFiles(
        tester,
        _page((c) => askDownloadLargeFile(c, 222298112), (_) {}),
        locale: const Locale('de'),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(
        find.text('Diese Datei ist 212 MB groß. Trotzdem herunterladen?'),
        findsOneWidget,
      );
      expect(find.text('Herunterladen'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
    });

    testWidgets('at the largest text the sheet stacks its buttons', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        _page((c) => askDownloadLargeFile(c, 222298112), (_) {}),
        textScale: 3,
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final download = tester.getRect(
        find.widgetWithText(FilledButton, 'Download'),
      );
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      expect(cancel.top, greaterThanOrEqualTo(download.bottom));
    });
  });

  group('secret question', () {
    testWidgets('titles the alert with the name and makes Cancel the default', (
      tester,
    ) async {
      bool? answer;
      await pumpFiles(
        tester,
        _page((c) => askOpenSecretFile(c, '.env'), (a) => answer = a),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.text('.env'), findsOneWidget);
      expect(
        find.text('This file may contain passwords or keys. Continue anyway?'),
        findsOneWidget,
      );
      final cancel = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Cancel'),
      );
      final carry = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Continue'),
      );
      expect(cancel.isDefaultAction, isTrue);
      expect(carry.isDefaultAction, isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });

    testWidgets('Continue answers yes', (tester) async {
      bool? answer;
      await pumpFiles(
        tester,
        _page((c) => askOpenSecretFile(c, '.env'), (a) => answer = a),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(answer, isTrue);
    });

    testWidgets('Android shows two text buttons, Cancel first', (tester) async {
      await pumpFiles(
        tester,
        _page((c) => askOpenSecretFile(c, '.env'), (_) {}),
        platform: TargetPlatform.android,
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

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
      expect(
        tester.getTopLeft(find.text('Cancel')).dx,
        lessThan(tester.getTopLeft(find.text('Continue')).dx),
      );
    });

    testWidgets('a Mac asks with an alert too', (tester) async {
      await pumpFiles(
        tester,
        _page((c) => askOpenSecretFile(c, 'api_token.txt'), (_) {}),
        platform: TargetPlatform.macOS,
        size: const Size(1000, 800),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.byType(AppAlertDialog), findsOneWidget);
      expect(find.text('api_token.txt'), findsOneWidget);
    });

    testWidgets('is German in German', (tester) async {
      await pumpFiles(
        tester,
        _page((c) => askOpenSecretFile(c, '.env'), (_) {}),
        locale: const Locale('de'),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Diese Datei enthält möglicherweise Passwörter oder Schlüssel. Trotzdem fortfahren?',
        ),
        findsOneWidget,
      );
      expect(find.text('Fortfahren'), findsOneWidget);
    });
  });

  group('link question', () {
    testWidgets('names the host, with Cancel as the default and Open', (
      tester,
    ) async {
      bool? answer;
      await pumpFiles(
        tester,
        _page((c) => confirmOpenLink(c, 'example.org'), (a) => answer = a),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.text('Open example.org?'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoDialogAction>(
              find.widgetWithText(CupertinoDialogAction, 'Cancel'),
            )
            .isDefaultAction,
        isTrue,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });
  });

  group('saved', () {
    testWidgets('a snack bar says Saved with the name', (tester) async {
      await pumpFiles(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFilesSaved(context, 'export.zip'),
            child: const Text('save'),
          ),
        ),
      );

      await tester.tap(find.text('save'));
      await tester.pump();

      expect(find.text('Saved export.zip.'), findsOneWidget);
    });
  });
}
