import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/whatsapp/whatsapp_pairing.dart';
import 'package:hermes_app/src/messaging/widgets/handset_qr_notice.dart';
import 'package:hermes_app/src/messaging/widgets/linked_account_card.dart';
import 'package:hermes_app/src/messaging/widgets/pairing_end.dart';
import 'package:hermes_app/src/messaging/widgets/pairing_stage_card.dart';
import 'package:hermes_app/src/messaging/widgets/scan_steps.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_saved_banner.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_setup_form.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';

import 'whatsapp_widget_host.dart';

/// Control and bidi characters, made at run time so no tool rewrites them in
/// the source: a right-to-left override, its pop, a bell and a zero-width
/// space.
final _rlo = String.fromCharCode(0x202E);
final _controls =
    'exited${_rlo}gnp.${String.fromCharCode(0x202C)} with code 1.'
    '${String.fromCharCode(0x07)}${String.fromCharCode(0x200B)}';

Widget _form({
  WhatsAppMode mode = WhatsAppMode.bot,
  ValueChanged<WhatsAppMode>? onMode,
  TextEditingController? numbers,
  WhatsAppNumbersIssue? issue,
  WhatsAppStartProblem? problem,
  String? serverText,
  bool starting = false,
  VoidCallback? onStart,
  VoidCallback? onStartAgain,
  bool handset = true,
}) => WhatsAppSetupForm(
  mode: mode,
  onModeChanged: onMode ?? (_) {},
  numbers: numbers ?? TextEditingController(),
  numbersIssue: issue,
  problem: problem,
  serverText: serverText,
  starting: starting,
  onStart: onStart ?? () {},
  onStartAgain: onStartAgain,
  handset: handset,
);

void main() {
  group('WhatsAppSetupForm', () {
    testWidgets('the mode sentences are the footer, the rows have one line '
        'each', (tester) async {
      await pumpWa(tester, _form());
      expect(find.text('Bot'), findsOneWidget);
      expect(find.text('Its own WhatsApp number'), findsOneWidget);
      expect(find.text('Self-chat'), findsOneWidget);
      expect(find.text('Your own number'), findsOneWidget);
      expect(
        find.text(
          'Bot: Hermes has its own WhatsApp number. The people you allow '
          'message that number. Self-chat: Hermes uses your own number. You '
          'talk to it in your chat with yourself.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the numbers field is labelled by its section header', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWa(tester, _form());
      // An Apple multi-line row shows only its value or hint, so the section
      // header is the visible label and the row carries the same words.
      expect(
        tester
            .widget<GroupedTextFieldRow>(find.byType(GroupedTextFieldRow))
            .label,
        'Allowed phone numbers',
      );
      expect(find.text('ALLOWED PHONE NUMBERS'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Allowed phone numbers')),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text('+49 151 2345678, +41 79 1234567'),
        findsOneWidget,
        reason: 'the hint shows the shape of the list',
      );
      handle.dispose();
    });

    testWidgets('Bot is picked first, a tap on Self-chat reports it', (
      tester,
    ) async {
      final picked = <WhatsAppMode>[];
      await pumpWa(tester, _form(onMode: picked.add));
      expect(
        tester
            .widget<RadioGroup<WhatsAppMode>>(
              find.byType(RadioGroup<WhatsAppMode>),
            )
            .groupValue,
        WhatsAppMode.bot,
      );
      await tester.tap(find.text('Self-chat'));
      expect(picked, [WhatsAppMode.selfChat]);
    });

    testWidgets('a blank list is valid: Start is enabled and sends nothing '
        'itself', (tester) async {
      var started = 0;
      await pumpWa(tester, _form(onStart: () => started++));
      await tester.tap(find.text('Start'));
      expect(started, 1);
    });

    testWidgets('the numbers field takes phone input and turns the keyboard '
        'helpers off', (tester) async {
      await pumpWa(tester, _form(), platform: TargetPlatform.android);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.minLines, 2);
    });

    testWidgets('Apple platforms get a keyboard with a comma', (tester) async {
      await pumpWa(tester, _form());
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, isNot(TextInputType.phone));
    });

    for (final (issue, text) in [
      (
        WhatsAppNumbersIssue.notPhoneNumber,
        'Enter phone numbers: digits, with an optional + at the start, '
            'separated by commas.',
      ),
      (
        WhatsAppNumbersIssue.everyone,
        'Letting everyone message Hermes is a server setting. Here you can '
            'only name phone numbers.',
      ),
    ]) {
      testWidgets('invalid numbers: $issue shows its line with an error '
          'icon, and Start is still the only button', (tester) async {
        await pumpWa(tester, _form(issue: issue));
        expect(find.text(text), findsOneWidget);
        expect(
          find.byIcon(AppIcons.error.apple),
          findsOneWidget,
          reason: 'status is an icon and words, never colour alone',
        );
        expect(find.byType(FilledButton), findsOneWidget);
      });
    }

    testWidgets('starting: the button stays, shows Starting... and is '
        'disabled; the form is locked', (tester) async {
      var started = 0;
      await pumpWa(tester, _form(starting: true, onStart: () => started++));
      expect(find.text('Starting...'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      await tester.tap(find.text('Starting...'), warnIfMissed: false);
      expect(started, 0);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('refused by the server: its text is the detail, Start is '
        'there again', (tester) async {
      await pumpWa(
        tester,
        _form(
          problem: WhatsAppStartProblem.refused,
          serverText: "mode must be 'bot'",
        ),
      );
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.error);
      expect(banner.title, "Couldn't start the setup.");
      expect(banner.detail, "mode must be 'bot'");
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('the server\'s text shows control and bidi characters', (
      tester,
    ) async {
      await pumpWa(
        tester,
        _form(problem: WhatsAppStartProblem.refused, serverText: _controls),
      );
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(
        banner.detail,
        'exited<U+202E>gnp.<U+202C> with code 1.<U+0007><U+200B>',
      );
    });

    testWidgets('offline: nothing was started, Start stays', (tester) async {
      await pumpWa(tester, _form(problem: WhatsAppStartProblem.offline));
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.warning);
      expect(banner.title, "You're offline.");
      expect(banner.detail, "Couldn't start the setup. Nothing was started.");
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('lost answer: Start again is the banner\'s filled button and '
        'the plain Start gives way', (tester) async {
      var again = 0;
      await pumpWa(
        tester,
        _form(
          problem: WhatsAppStartProblem.lostAnswer,
          onStartAgain: () => again++,
        ),
      );
      expect(find.text("Couldn't confirm the setup started."), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text('Start again'));
      expect(again, 1);
    });
  });

  group('PairingEnd', () {
    Future<void> end(
      WidgetTester tester,
      PairingEndKind kind, {
      String? text,
      bool duringApply = false,
      VoidCallback? onStartAgain,
      VoidCallback? onBack,
    }) => pumpWa(
      tester,
      PairingEnd(
        kind: kind,
        serverText: text,
        duringApply: duringApply,
        onStartAgain: onStartAgain,
        onBack: onBack,
      ),
    );

    for (final (kind, title, detail) in [
      (
        PairingEndKind.expired,
        'The code expired',
        'A setup closes after 10 minutes. Start again to get a new code.',
      ),
      (
        PairingEndKind.superseded,
        'Another setup replaced this one',
        'WhatsApp was set up again from another device or window.',
      ),
      (
        PairingEndKind.gone,
        'This setup is no longer on the server',
        'It may have expired, or the server restarted.',
      ),
    ]) {
      testWidgets('$kind: its title and detail, and a filled Start again', (
        tester,
      ) async {
        var again = 0;
        await end(tester, kind, onStartAgain: () => again++);
        expect(find.text(title), findsOneWidget);
        expect(find.text(detail), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.text('Back'), findsNothing);
        await tester.tap(find.text('Start again'));
        expect(again, 1);
      });
    }

    testWidgets('gone while saving says the settings may not be saved', (
      tester,
    ) async {
      await end(tester, PairingEndKind.gone, duringApply: true);
      expect(
        find.text('The settings may not have been saved.'),
        findsOneWidget,
      );
    });

    for (final (kind, title) in [
      (
        PairingEndKind.unsupported,
        'This server cannot link WhatsApp from the app',
      ),
      (PairingEndKind.profileDeleted, "This chat's profile no longer exists"),
    ]) {
      testWidgets('$kind offers no retry, only an outlined Back', (
        tester,
      ) async {
        var back = 0;
        await end(tester, kind, onBack: () => back++);
        expect(find.text(title), findsOneWidget);
        expect(find.text('Start again'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsOneWidget);
        await tester.tap(find.text('Back'));
        expect(back, 1);
      });
    }

    testWidgets('the server\'s text shows control and bidi characters '
        'visibly and wraps', (tester) async {
      await end(tester, PairingEndKind.error, text: _controls);
      expect(find.text('WhatsApp setup stopped'), findsOneWidget);
      final shown = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(shown, 'exited<U+202E>gnp.<U+202C> with code 1.<U+0007><U+200B>');
      for (final unit in shown.codeUnits) {
        expect(unit >= 0x20 && unit != 0x202E && unit != 0x200B, isTrue);
      }
    });

    testWidgets('an error with no text says so', (tester) async {
      await end(tester, PairingEndKind.error);
      expect(find.text('The server gave no reason.'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('ten long log lines wrap instead of overflowing', (
      tester,
    ) async {
      final lines = List.generate(
        10,
        (i) =>
            'npm ERR! /srv/invented/hermes/home/.npm/_logs/$i-debug.log '
            'and a very long tail that has to wrap ${'x' * 80}',
      ).join('\n');
      await end(tester, PairingEndKind.error, text: lines);
      expect(tester.takeException(), isNull);
    });
  });

  group('LinkedAccountCard', () {
    testWidgets('a new account: success banner, name and number', (
      tester,
    ) async {
      await pumpWa(
        tester,
        const LinkedAccountCard(
          alreadyLinked: false,
          name: 'Mara Example',
          phone: '15555550100',
        ),
      );
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.success);
      expect(banner.title, 'WhatsApp is linked.');
      expect(find.text('Mara Example'), findsOneWidget);
      expect(find.text('+15555550100'), findsOneWidget);
    });

    testWidgets('already linked is neutral and says the app cannot unlink', (
      tester,
    ) async {
      await pumpWa(
        tester,
        const LinkedAccountCard(
          alreadyLinked: true,
          name: 'Mara Example',
          phone: '15555550100',
        ),
      );
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.neutral);
      expect(banner.title, 'Already linked');
      expect(banner.detail, contains("can't unlink or replace"));
      expect(find.text('WhatsApp is linked.'), findsNothing);
    });

    testWidgets('missing fields read as not given', (tester) async {
      await pumpWa(tester, const LinkedAccountCard(alreadyLinked: false));
      expect(find.text('Name not given'), findsOneWidget);
      expect(find.text('Number not given'), findsOneWidget);
    });

    testWidgets('a long name wraps under its title, the number is never '
        'cut, at the largest text', (tester) async {
      const name =
          'Maximilian Alexander von Beispielstein-Musterfrau, Bakery orders';
      await pumpWa(
        tester,
        const LinkedAccountCard(
          alreadyLinked: false,
          name: name,
          phone: '15555550100',
        ),
        textScaler: const TextScaler.linear(3),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(name), findsOneWidget);
      final number = tester.widget<Text>(find.text('+15555550100'));
      expect(number.overflow, isNot(TextOverflow.ellipsis));
      // Stacked under its title.
      expect(
        tester.getTopLeft(find.text('+15555550100')).dy,
        greaterThan(tester.getTopLeft(find.text('Number')).dy),
      );
    });

    testWidgets('control characters in the name are shown, not obeyed', (
      tester,
    ) async {
      await pumpWa(
        tester,
        LinkedAccountCard(alreadyLinked: false, name: 'Mara$_rlo', phone: '1'),
      );
      expect(find.text('Mara<U+202E>'), findsOneWidget);
    });
  });

  group('the smaller widgets', () {
    testWidgets('PairingStageCard: the stage word and Cancel', (tester) async {
      var cancelled = 0;
      for (final (stage, word) in [
        (WhatsAppWorkStage.installing, 'Installing'),
        (WhatsAppWorkStage.starting, 'Starting'),
        (WhatsAppWorkStage.other, 'Working...'),
      ]) {
        await pumpWa(
          tester,
          PairingStageCard(stage: stage, onCancel: () => cancelled++),
        );
        expect(
          find.text('Preparing WhatsApp on your server...'),
          findsOneWidget,
        );
        expect(find.text(word), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
      }
      await tester.tap(find.text('Cancel setup'));
      expect(cancelled, 1);
    });

    testWidgets('HandsetQrNotice: before the tap a neutral banner and the '
        'filled button; after it one muted line', (tester) async {
      var shown = 0;
      await pumpWa(
        tester,
        HandsetQrNotice(revealed: false, onShow: () => shown++),
      );
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.neutral);
      expect(banner.icon, AppIcons.call);
      await tester.tap(find.text('Show QR code'));
      expect(shown, 1);
      await pumpWa(tester, HandsetQrNotice(revealed: true, onShow: () {}));
      expect(find.byType(AppBanner), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(
        find.text('Scan this with the phone that has WhatsApp.'),
        findsOneWidget,
      );
    });

    testWidgets('ScanSteps: four numbered steps', (tester) async {
      await pumpWa(tester, const ScanSteps());
      for (final text in [
        'Open WhatsApp on the phone that has your account.',
        'Tap Settings, then Linked devices.',
        'Tap Link a device.',
        'Point the camera at this code.',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      for (final n in ['1.', '2.', '3.', '4.']) {
        expect(find.text(n), findsOneWidget);
      }
    });
  });

  group('WhatsAppSavedBanner', () {
    Future<void> saved(
      WidgetTester tester,
      WhatsAppSavedKind kind, {
      String? error,
      VoidCallback? onOpenServer,
    }) => pumpWa(
      tester,
      WhatsAppSavedBanner(
        kind: kind,
        restartError: error,
        onOpenServer: onOpenServer,
        onClose: () {},
      ),
    );

    testWidgets('a requested restart is a success, and not a claim that the '
        'gateway restarted', (tester) async {
      await saved(tester, WhatsAppSavedKind.restartRequested);
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.success);
      expect(banner.title, 'WhatsApp is set up.');
      expect(
        banner.detail,
        'A restart of the messaging gateway was requested.',
      );
    });

    for (final (kind, detail) in [
      (
        WhatsAppSavedKind.noRestart,
        'No restart was requested. Restart the messaging gateway from Server.',
      ),
      (
        WhatsAppSavedKind.restartMayBeNeeded,
        "A restart was requested; if WhatsApp doesn't answer, restart it from Server.",
      ),
      (
        WhatsAppSavedKind.unknownRestart,
        "Restart the messaging gateway from Server if WhatsApp doesn't answer.",
      ),
    ]) {
      testWidgets('$kind is a warning with the Server hint', (tester) async {
        await saved(tester, kind, onOpenServer: () {});
        final banner = tester.widget<AppBanner>(find.byType(AppBanner));
        expect(banner.tone, AppBannerTone.warning);
        expect(banner.title, 'WhatsApp is saved.');
        expect(banner.detail, detail);
        expect(banner.detail.toLowerCase(), isNot(contains('has restarted')));
        expect(find.text('Open Server'), findsOneWidget);
      });
    }

    testWidgets('Open Server shows only where the screen exists; the restart '
        'error is appended as given, controls shown', (tester) async {
      await saved(tester, WhatsAppSavedKind.noRestart, error: 'refused$_rlo');
      expect(find.text('Open Server'), findsNothing);
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.detail, endsWith(' refused<U+202E>'));
      expect(find.byTooltip('Close'), findsOneWidget);
    });
  });
}
