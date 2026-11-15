import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/whatsapp/whatsapp_pairing.dart';
import 'package:hermes_app/src/messaging/widgets/qr_code_card.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_pairing_view.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_setup_form.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

import 'whatsapp_widget_host.dart';

class _Calls {
  final taps = <String>[];
}

WhatsAppPairingView _view(
  WhatsAppViewPhase phase, {
  _Calls? calls,
  bool handset = true,
  QrCodeVisibility visibility = QrCodeVisibility.shown,
  Duration? timeLeft = const Duration(minutes: 8, seconds: 42),
  bool paused = false,
  bool offline = false,
  bool alreadyLinked = false,
  WhatsAppFinishStatus finish = WhatsAppFinishStatus.idle,
  bool refreshing = false,
  bool refreshFailed = false,
  bool goneDuringApply = false,
  String? serverText,
  WhatsAppMode mode = WhatsAppMode.bot,
  bool selfChatBlank = false,
  WhatsAppStartProblem? startProblem,
  WhatsAppNumbersIssue? issue,
  WhatsAppWorkStage stage = WhatsAppWorkStage.installing,
}) {
  void tap(String name) => calls?.taps.add(name);
  return WhatsAppPairingView(
    phase: phase,
    handset: handset,
    mode: mode,
    numbers: TextEditingController(),
    numbersIssue: issue,
    startProblem: startProblem,
    serverText: serverText,
    workStage: stage,
    codeVisibility: visibility,
    qrPayload: waPayload,
    timeLeft: timeLeft,
    paused: paused,
    offline: offline,
    alreadyLinked: alreadyLinked,
    accountName: 'Mara Example',
    accountPhone: '15555550100',
    profile: 'work',
    selfChatBlankNumbers: selfChatBlank,
    finish: finish,
    refreshing: refreshing,
    refreshFailed: refreshFailed,
    goneDuringApply: goneDuringApply,
    onModeChanged: (_) {},
    onStart: () => tap('start'),
    onStartAgain: () => tap('startAgain'),
    onCancel: () => tap('cancel'),
    onShowQr: () => tap('show'),
    onFinish: () => tap('finish'),
    onCheck: () => tap('check'),
    onBack: () => tap('back'),
  );
}

Future<void> _pump(
  WidgetTester tester,
  WhatsAppPairingView view, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  TextScaler? textScaler,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpWa(
    tester,
    view,
    platform: platform,
    locale: locale,
    textScaler: textScaler,
    scroll: false,
  );
}

void main() {
  group('the code phase', () {
    testWidgets('a handset shows the notice and no code before the tap', (
      tester,
    ) async {
      final calls = _Calls();
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.waiting,
          calls: calls,
          visibility: QrCodeVisibility.needsTap,
        ),
      );
      expect(find.byType(QrCodePattern), findsNothing);
      expect(find.byType(QrCodeTile), findsNothing);
      expect(find.text('Show QR code'), findsOneWidget);
      expect(find.text('Cancel setup'), findsOneWidget);
      await tester.tap(find.text('Show QR code'));
      expect(calls.taps, ['show']);
    });

    testWidgets('after the tap the notice is one line above the code, the '
        'steps and Cancel', (tester) async {
      await _pump(tester, _view(WhatsAppViewPhase.waiting));
      expect(find.byType(QrCodePattern), findsOneWidget);
      expect(
        find.text('Scan this with the phone that has WhatsApp.'),
        findsOneWidget,
      );
      expect(find.byType(AppBanner), findsNothing);
      expect(find.text('Waiting for a scan'), findsOneWidget);
      expect(find.text('Setup closes in 8:42'), findsOneWidget);
      expect(find.text('Tap Link a device.'), findsOneWidget);
      expect(find.text('Cancel setup'), findsOneWidget);
    });

    testWidgets('a tablet or a computer shows the code at once', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(WhatsAppViewPhase.waiting, handset: false),
        size: const Size(800, 900),
      );
      expect(find.byType(QrCodePattern), findsOneWidget);
      expect(find.text('Show QR code'), findsNothing);
    });

    testWidgets('hidden on a computer: no code is built, the line says it '
        'returns by itself', (tester) async {
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.waiting,
          handset: false,
          visibility: QrCodeVisibility.hidden,
        ),
        size: const Size(800, 900),
      );
      expect(find.byType(QrCodePattern), findsNothing);
      expect(
        find.text('Shows again when the app is unlocked and in front.'),
        findsOneWidget,
      );
      expect(find.text('Show QR code'), findsNothing);
    });

    testWidgets('from 640 wide the tile sits left of the status and the '
        'steps; below it, or at text scale 2, they stack', (tester) async {
      await _pump(
        tester,
        _view(WhatsAppViewPhase.waiting, handset: false),
        size: const Size(1000, 900),
      );
      final tile = tester.getRect(find.byType(QrCodeTile));
      expect(tile.size, const Size(kQrTileSizeWide, kQrTileSizeWide));
      expect(
        tester.getTopLeft(find.text('Waiting for a scan')).dx,
        greaterThan(tile.right),
      );
      expect(
        tester.getTopLeft(find.text('Cancel setup')).dx,
        greaterThan(tile.right),
      );

      await _pump(
        tester,
        _view(WhatsAppViewPhase.waiting, handset: false),
        size: const Size(600, 900),
      );
      expect(
        tester.getTopLeft(find.text('Waiting for a scan')).dy,
        greaterThan(tester.getRect(find.byType(QrCodeTile)).bottom),
      );

      await _pump(
        tester,
        _view(WhatsAppViewPhase.waiting, handset: false),
        size: const Size(1000, 900),
        textScaler: const TextScaler.linear(2),
      );
      expect(
        tester.getTopLeft(find.text('Waiting for a scan')).dy,
        greaterThan(tester.getRect(find.byType(QrCodeTile)).bottom),
      );
      expect(
        tester.getSize(find.byType(QrCodeTile)),
        const Size(kQrTileSize, kQrTileSize),
        reason: 'the tile does not grow with the text',
      );
    });

    testWidgets('the last minute shows the warning banner and keeps the code', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(WhatsAppViewPhase.waiting, timeLeft: const Duration(seconds: 42)),
      );
      expect(find.text('Setup closes in 0:42.'), findsOneWidget);
      expect(find.byType(QrCodePattern), findsOneWidget);
    });
  });

  group('the notes above the body', () {
    testWidgets('paused: a neutral banner with a detail, while preparing and '
        'with a code', (tester) async {
      for (final phase in [
        WhatsAppViewPhase.working,
        WhatsAppViewPhase.waiting,
      ]) {
        await _pump(tester, _view(phase, paused: true));
        final banner = tester.widget<AppBanner>(find.byType(AppBanner));
        expect(banner.tone, AppBannerTone.neutral);
        expect(banner.title, 'Paused while the app was away.');
        expect(banner.detail, 'Checking again now. The code may have changed.');
      }
    });

    testWidgets('offline replaces paused, with the line that fits the '
        'phase', (tester) async {
      await _pump(
        tester,
        _view(WhatsAppViewPhase.working, paused: true, offline: true),
      );
      var banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.warning);
      expect(banner.title, "You're offline.");
      expect(banner.detail, "Checking again when you're back.");
      await _pump(
        tester,
        _view(WhatsAppViewPhase.waiting, paused: true, offline: true),
      );
      banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.detail, 'This code may be out of date.');
      expect(find.byType(QrCodePattern), findsOneWidget);
    });

    testWidgets('no polling note on the form or an end state', (tester) async {
      await _pump(tester, _view(WhatsAppViewPhase.setup, paused: true));
      expect(find.byType(AppBanner), findsNothing);
      await _pump(tester, _view(WhatsAppViewPhase.expired, offline: true));
      expect(find.byType(AppBanner), findsNothing);
    });
  });

  group('linked and Finish', () {
    testWidgets('Finish and the note about leaving; the account', (
      tester,
    ) async {
      final calls = _Calls();
      await _pump(tester, _view(WhatsAppViewPhase.connected, calls: calls));
      expect(find.text('Mara Example'), findsOneWidget);
      expect(find.text('+15555550100'), findsOneWidget);
      expect(
        find.text(
          'Saves the mode and allowed numbers for work, switches WhatsApp on, '
          'and asks the messaging gateway to restart.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "If you leave now, the account stays linked on the server, but the setup isn't saved.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Finish'));
      expect(calls.taps, ['finish']);
      expect(find.text('Start again'), findsNothing);
    });

    testWidgets('Self-chat with a blank list says the allowed number is '
        'your own', (tester) async {
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.connected,
          mode: WhatsAppMode.selfChat,
          selfChatBlank: true,
        ),
      );
      expect(find.textContaining('Allowed: your own number.'), findsOneWidget);
    });

    testWidgets('already linked has no Start again and no new scan', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(WhatsAppViewPhase.connected, alreadyLinked: true),
      );
      expect(find.text('Already linked'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.byType(QrCodePattern), findsNothing);
    });

    testWidgets('saving: Finish becomes a disabled Saving... row', (
      tester,
    ) async {
      final calls = _Calls();
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.connected,
          calls: calls,
          finish: WhatsAppFinishStatus.applying,
        ),
      );
      expect(find.text('Saving...'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
      await tester.tap(find.text('Saving...'), warnIfMissed: false);
      expect(calls.taps, isEmpty);
    });

    testWidgets('refused: the server\'s text in an error banner and Finish '
        'again', (tester) async {
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.connected,
          finish: WhatsAppFinishStatus.refused,
          serverText: 'Failed to save WhatsApp setup.',
        ),
      );
      final banner = tester
          .widgetList<AppBanner>(find.byType(AppBanner))
          .firstWhere((b) => b.tone == AppBannerTone.error);
      expect(banner.title, "Couldn't save the setup.");
      expect(banner.detail, 'Failed to save WhatsApp setup.');
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('lost answer: Check, and no Finish', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.connected,
          calls: calls,
          finish: WhatsAppFinishStatus.lostAnswer,
        ),
      );
      expect(
        find.text('Could not confirm the setup was saved.'),
        findsOneWidget,
      );
      expect(find.text('Finish'), findsNothing);
      await tester.tap(find.text('Check'));
      expect(calls.taps, ['check']);
    });

    testWidgets('checking keeps the banner and shows a busy Check', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.connected,
          finish: WhatsAppFinishStatus.checking,
        ),
      );
      expect(find.text('Checking...'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
    });

    testWidgets('Check could not confirm: try again, never "saved"', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.connected,
          finish: WhatsAppFinishStatus.checkFailed,
        ),
      );
      expect(find.text("Couldn't confirm. Try again."), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);
      expect(find.text('WhatsApp is saved.'), findsNothing);
    });

    testWidgets('not saved yet offers Start again', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _view(
          WhatsAppViewPhase.connected,
          calls: calls,
          finish: WhatsAppFinishStatus.notSavedYet,
        ),
      );
      expect(find.text('Not saved yet.'), findsOneWidget);
      await tester.tap(find.text('Start again'));
      expect(calls.taps, ['startAgain']);
    });

    testWidgets('reading the account again shows a line and no Finish; when '
        'that fails, Start again', (tester) async {
      await _pump(tester, _view(WhatsAppViewPhase.connected, refreshing: true));
      expect(find.text('Reading the account again...'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
      await _pump(
        tester,
        _view(WhatsAppViewPhase.connected, refreshFailed: true),
      );
      expect(find.text("Couldn't read the account."), findsOneWidget);
      expect(find.text('Start again'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
    });

    testWidgets('the setup gone while saving: the settings may not be '
        'saved', (tester) async {
      await _pump(tester, _view(WhatsAppViewPhase.gone, goneDuringApply: true));
      expect(
        find.text('The settings may not have been saved.'),
        findsOneWidget,
      );
      expect(find.text('Start again'), findsOneWidget);
    });
  });

  group('the form and the ends', () {
    testWidgets('a lost start shows the form with its values and Start again', (
      tester,
    ) async {
      await _pump(tester, _view(WhatsAppViewPhase.startLost));
      expect(find.text("Couldn't confirm the setup started."), findsOneWidget);
      expect(find.text('Bot'), findsOneWidget);
    });

    testWidgets('each end state is shown', (tester) async {
      for (final (phase, title) in [
        (WhatsAppViewPhase.failed, 'WhatsApp setup stopped'),
        (WhatsAppViewPhase.expired, 'The code expired'),
        (WhatsAppViewPhase.superseded, 'Another setup replaced this one'),
        (WhatsAppViewPhase.gone, 'This setup is no longer on the server'),
        (
          WhatsAppViewPhase.unsupported,
          'This server cannot link WhatsApp from the app',
        ),
        (
          WhatsAppViewPhase.profileDeleted,
          "This chat's profile no longer exists",
        ),
      ]) {
        await _pump(tester, _view(phase, serverText: 'invented text'));
        expect(find.text(title), findsOneWidget, reason: '$phase');
      }
    });

    testWidgets('the payload does not exist in the tree when hidden', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(WhatsAppViewPhase.waiting, visibility: QrCodeVisibility.hidden),
      );
      expect(WhatsAppPairingView.new.toString(), isNot(contains('DEMO')));
      final view = tester.widget<WhatsAppPairingView>(
        find.byType(WhatsAppPairingView),
      );
      expect(view.qrPayload, isNull);
    });
  });

  group('targets', () {
    for (final MapEntry(key: platform, value: minimum) in waTargets.entries) {
      testWidgets('every button is at least $minimum on $platform', (
        tester,
      ) async {
        final states = <WhatsAppPairingView>[
          _view(WhatsAppViewPhase.setup),
          _view(WhatsAppViewPhase.starting),
          _view(WhatsAppViewPhase.startLost),
          _view(WhatsAppViewPhase.working),
          _view(
            WhatsAppViewPhase.waiting,
            visibility: QrCodeVisibility.needsTap,
          ),
          _view(WhatsAppViewPhase.waiting),
          _view(WhatsAppViewPhase.connected),
          _view(
            WhatsAppViewPhase.connected,
            finish: WhatsAppFinishStatus.lostAnswer,
          ),
          _view(WhatsAppViewPhase.expired),
          _view(WhatsAppViewPhase.unsupported),
        ];
        for (final view in states) {
          await _pump(tester, view, platform: platform);
          final buttons = [
            ...find.byType(FilledButton).evaluate(),
            ...find.byType(OutlinedButton).evaluate(),
          ];
          expect(buttons, isNotEmpty, reason: '${view.phase}');
          for (final element in buttons) {
            expect(
              tester.getSize(find.byWidget(element.widget)).height,
              greaterThanOrEqualTo(minimum),
              reason: '${view.phase} on $platform',
            );
          }
        }
      });
    }
  });

  group('German at the largest text', () {
    testWidgets('every phase builds without overflow', (tester) async {
      final states = <WhatsAppPairingView>[
        _view(WhatsAppViewPhase.setup),
        _view(WhatsAppViewPhase.setup, issue: WhatsAppNumbersIssue.everyone),
        _view(
          WhatsAppViewPhase.setup,
          startProblem: WhatsAppStartProblem.refused,
          serverText: 'invented text',
        ),
        _view(WhatsAppViewPhase.starting),
        _view(WhatsAppViewPhase.startLost),
        _view(WhatsAppViewPhase.working, paused: true),
        _view(WhatsAppViewPhase.working, offline: true),
        _view(WhatsAppViewPhase.waiting, visibility: QrCodeVisibility.needsTap),
        _view(WhatsAppViewPhase.waiting),
        _view(
          WhatsAppViewPhase.waiting,
          timeLeft: const Duration(seconds: 42),
          offline: true,
        ),
        _view(
          WhatsAppViewPhase.waiting,
          handset: false,
          visibility: QrCodeVisibility.hidden,
        ),
        _view(WhatsAppViewPhase.connected),
        _view(WhatsAppViewPhase.connected, alreadyLinked: true),
        _view(
          WhatsAppViewPhase.connected,
          finish: WhatsAppFinishStatus.lostAnswer,
        ),
        _view(
          WhatsAppViewPhase.connected,
          finish: WhatsAppFinishStatus.refused,
          serverText: 'invented text',
        ),
        _view(WhatsAppViewPhase.connected, refreshFailed: true),
        _view(WhatsAppViewPhase.failed, serverText: 'invented text'),
        _view(WhatsAppViewPhase.expired),
        _view(WhatsAppViewPhase.superseded),
        _view(WhatsAppViewPhase.gone, goneDuringApply: true),
        _view(WhatsAppViewPhase.unsupported),
        _view(WhatsAppViewPhase.profileDeleted),
      ];
      for (final platform in waTargets.keys) {
        for (final view in states) {
          await _pump(
            tester,
            view,
            platform: platform,
            locale: const Locale('de'),
            textScaler: const TextScaler.linear(3),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${view.phase} on $platform',
          );
        }
      }
    });
  });
}
