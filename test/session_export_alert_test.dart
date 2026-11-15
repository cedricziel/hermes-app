import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/session_export_alert.dart';
import 'package:hermes_app/src/chat/widgets/session_export_failure.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/busy_bar.dart';

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
      _host(const SessionExportProgress(receivedBytes: 12 * 1024 * 1024)),
    );
    expect(find.text('Preparing the export…'), findsOneWidget);
    expect(find.byType(AppDialogAction), findsOneWidget);
    expect(tester.widget<AppDialogAction>(_action('Cancel')).isDefault, isTrue);
    expect(find.text('Downloaded 12 MB'), findsOneWidget);
    expect(find.text('Still waiting for Hermes.'), findsNothing);

    await tester.pumpWidget(_host(const SessionExportProgress(stalled: true)));
    expect(find.text('Still waiting for Hermes.'), findsOneWidget);
    expect(find.textContaining('Downloaded'), findsNothing);

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

  const english = <SessionExportFailure, (String, String)>{
    SessionExportFailure.gone: (
      'Chat not on the server',
      'This chat is no longer on the server. Nothing was saved.',
    ),
    SessionExportFailure.unsupported: (
      "This server can't export chats",
      'It may be running an older version of Hermes. Nothing was saved.',
    ),
    SessionExportFailure.profileMissing: (
      'Profile not found',
      "The profile this chat belongs to doesn't exist on the server any more. Nothing was saved.",
    ),
    SessionExportFailure.profileInvalid: (
      'Profile name not valid',
      "Hermes didn't accept this chat's profile name, so it couldn't read the chat. Nothing was saved.",
    ),
    SessionExportFailure.unreadable: (
      "Hermes can't read its chats",
      "The server's chat store couldn't be read. Check the server, then try again. Nothing was saved.",
    ),
    SessionExportFailure.lost: (
      "Couldn't confirm the export",
      "Hermes didn't answer in time. Nothing was saved.",
    ),
    SessionExportFailure.incomplete: (
      'The export was incomplete',
      'The file stopped before the end, so nothing was saved.',
    ),
    SessionExportFailure.offline: (
      "You're offline",
      'Connect to the internet or your server, then try again. Nothing was saved.',
    ),
    SessionExportFailure.failed: (
      "Couldn't export this chat",
      'Hermes answered with an error. Nothing was saved.',
    ),
  };

  testWidgets('English title and message of every failure kind', (
    tester,
  ) async {
    expect(english.keys.toSet(), failures.toSet());
    for (final MapEntry(key: kind, value: (title, message))
        in english.entries) {
      await tester.pumpWidget(_host(SessionExportFailed(kind)));
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect((dialog.title! as Text).data, title, reason: kind.name);
      expect(find.text(message), findsOneWidget, reason: kind.name);
    }
  });

  testWidgets('every button calls only its own callback', (tester) async {
    for (final kind in failures) {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final log = <String>[];
        await tester.pumpWidget(
          _host(SessionExportFailed(kind), log: log, platform: platform),
        );
        await tester.tap(find.text('Close'));
        expect(log, ['close'], reason: '${kind.name} $platform');
        if (kind.canRetry) {
          await tester.tap(find.text('Try again'));
          expect(log, ['close', 'retry'], reason: '${kind.name} $platform');
        }
      }
    }
    final log = <String>[];
    await tester.pumpWidget(_host(const SessionExportProgress(), log: log));
    await tester.tap(find.text('Cancel'));
    expect(log, ['cancel']);
  });

  testWidgets('progress says what is happening and shows one bar', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SessionExportProgress()));
    expect(
      find.text('Hermes is sending the file. A long chat can take a while.'),
      findsOneWidget,
    );
    expect(find.byType(BusyBar), findsOneWidget);
  });

  testWidgets('the bytes and stalled lines are live regions', (tester) async {
    final live = find.descendant(
      of: find.byType(SessionExportAlert),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        const SessionExportProgress(
          receivedBytes: 12 * 1024 * 1024 + 300 * 1024,
        ),
      ),
    );
    expect(live, findsOneWidget);
    final bytes = tester.getSemantics(live);
    expect(bytes.flagsCollection.isLiveRegion, isTrue);
    // Coarse on purpose (announcedReceivedBytes: steps of 10 MB above 10 MB):
    // the screen shows 12 MB, the announcement says 10 MB.
    expect(find.text('Downloaded 12 MB'), findsOneWidget);
    expect(bytes.label, 'Downloaded 10 MB');

    await tester.pumpWidget(_host(const SessionExportProgress(stalled: true)));
    expect(live, findsOneWidget);
    final stalled = tester.getSemantics(live);
    expect(stalled.flagsCollection.isLiveRegion, isTrue);
    expect(stalled.label, 'Still waiting for Hermes.');
    handle.dispose();
  });
}
