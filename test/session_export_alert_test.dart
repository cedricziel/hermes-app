import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/session_export_alert.dart';
import 'package:hermes_app/src/chat/widgets/session_export_failure.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

Widget _host(
  SessionExportPhase phase, {
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
  List<String>? log,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(platform: platform),
  home: Scaffold(
    body: SessionExportAlert(
      phase: phase,
      onConfirm: () => log?.add('confirm'),
      onCancel: () => log?.add('cancel'),
      onRetry: () => log?.add('retry'),
      onClose: () => log?.add('close'),
    ),
  ),
);

Finder _action(String label) => find.widgetWithText(AppDialogAction, label);

void main() {
  const failures = SessionExportFailure.values;

  test('the enum has the nine kinds and Try again only where it can help', () {
    expect(failures, hasLength(9));
    expect(failures.where((k) => !k.canRetry), [
      SessionExportFailure.gone,
      SessionExportFailure.unsupported,
      SessionExportFailure.profileMissing,
      SessionExportFailure.profileInvalid,
    ]);
  });

  testWidgets('Cancel is the default and a text button on Material', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_host(const SessionExportConfirm(), log: log));
    final cancel = tester.widget<AppDialogAction>(_action('Cancel'));
    expect(cancel.isDefault, isTrue);
    expect(cancel.filledOnMaterial, isFalse);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Export'), findsOneWidget);
    // Export is never the default, so Enter cannot start it by reflex.
    expect(
      tester.widget<AppDialogAction>(_action('Export')).isDefault,
      isFalse,
    );

    await tester.tap(find.text('Export'));
    await tester.tap(find.text('Cancel'));
    expect(log, ['confirm', 'cancel']);
  });

  testWidgets('Cancel is the default on Apple platforms too', (tester) async {
    await tester.pumpWidget(
      _host(const SessionExportConfirm(), platform: TargetPlatform.iOS),
    );
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final cancel = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Cancel'),
    );
    expect(cancel.isDefaultAction, isTrue);
  });

  testWidgets('progress shows Cancel only, bytes and the stalled line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SessionExportProgress(
          stalled: true,
          receivedBytes: 12 * 1024 * 1024,
        ),
      ),
    );
    expect(find.text('Preparing the export…'), findsOneWidget);
    expect(find.byType(AppDialogAction), findsOneWidget);
    expect(tester.widget<AppDialogAction>(_action('Cancel')).isDefault, isTrue);
    expect(find.text('Downloaded 12 MB'), findsOneWidget);
    expect(find.text('Still waiting for Hermes.'), findsOneWidget);

    await tester.pumpWidget(_host(const SessionExportProgress()));
    expect(find.textContaining('Downloaded'), findsNothing);
    expect(find.text('Still waiting for Hermes.'), findsNothing);
  });

  testWidgets('the alert can be popped except while it is in progress', (
    tester,
  ) async {
    bool canPop(SessionExportPhase phase) {
      return phase is! SessionExportProgress;
    }

    for (final phase in <SessionExportPhase>[
      const SessionExportConfirm(),
      const SessionExportProgress(),
      const SessionExportFailed(SessionExportFailure.lost),
    ]) {
      await tester.pumpWidget(_host(phase));
      final scope = tester.widget<PopScope>(find.byType(PopScope).last);
      expect(scope.canPop, canPop(phase), reason: '$phase');
    }
  });

  for (final kind in failures) {
    testWidgets(
      'failure ${kind.name}: Close, ${kind.canRetry ? 'with' : 'without'} Try again',
      (tester) async {
        final log = <String>[];
        await tester.pumpWidget(_host(SessionExportFailed(kind), log: log));
        final close = tester.widget<AppDialogAction>(_action('Close'));
        expect(close.isDefault, isTrue);
        expect(close.filledOnMaterial, isFalse);
        expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
        expect(
          _action('Try again'),
          kind.canRetry ? findsOneWidget : findsNothing,
        );
        expect(find.byType(FilledButton), findsNothing);
        // Nothing was saved, and the message never prints a status or a path.
        expect(find.textContaining('othing was saved'), findsOneWidget);

        if (kind.canRetry) {
          // Close is first, Try again second.
          expect(
            tester.getTopLeft(_action('Close')).dx,
            lessThan(tester.getTopLeft(_action('Try again')).dx),
          );
          await tester.tap(find.text('Try again'));
          expect(log, ['retry']);
        }
      },
    );
  }

  testWidgets('German builds each failure with its own title', (tester) async {
    final titles = <String>{};
    for (final kind in failures) {
      await tester.pumpWidget(
        _host(SessionExportFailed(kind), locale: const Locale('de')),
      );
      final title =
          tester.widget<AlertDialog>(find.byType(AlertDialog)).title! as Text;
      titles.add(title.data!);
      expect(find.text('Schließen'), findsOneWidget);
    }
    expect(titles, hasLength(9));
  });

  testWidgets('the alert shows its own strings only, never a chat title', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SessionExportConfirm()));
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(SessionExportAlert),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toSet();
    expect(texts, hasLength(4));
    expect(
      texts,
      containsAll(<String?>['Export this chat as JSON?', 'Cancel', 'Export']),
    );
  });
}
