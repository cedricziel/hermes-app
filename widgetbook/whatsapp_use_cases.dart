import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/whatsapp/whatsapp_pairing.dart';
import 'package:hermes_app/src/messaging/widgets/handset_qr_notice.dart';
import 'package:hermes_app/src/messaging/widgets/linked_account_card.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/messaging/widgets/pairing_end.dart';
import 'package:hermes_app/src/messaging/widgets/pairing_stage_card.dart';
import 'package:hermes_app/src/messaging/widgets/qr_code_card.dart';
import 'package:hermes_app/src/messaging/widgets/scan_steps.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_finish_question.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_pairing_view.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_saved_banner.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_setup_form.dart';
import 'package:hermes_app/src/widgets/adaptive_back_button.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'host.dart';

// Invented sample data: the catalog is public. The code's text is not a real
// WhatsApp payload and encodes nothing; the names and numbers are made up
// (555-01xx is the range reserved for fiction).
const _payload =
    'DEMO-NOT-A-REAL-QR,2@invented-segment-one-0001,'
    'invented-segment-two-0002==,invented-segment-three-0003=';
const _name = 'Mara Example';
const _phone = '15555550100';
const _longName =
    'Maximilian Alexander von Beispielstein-Musterfrau, Bakery orders desk';
const _profile = 'work';
const _numbersText = '+1 555 555 0100, +1 555 555 0101';
const _timeLeft = Duration(minutes: 8, seconds: 42);
const _expiring = Duration(seconds: 42);

const _installFailed =
    'npm install failed for WhatsApp bridge:\n'
    'npm ERR! code ENOTFOUND\n'
    'npm ERR! syscall getaddrinfo\n'
    'npm ERR! errno ENOTFOUND\n'
    'npm ERR! network request to https://registry.invented.example/ failed\n'
    'npm ERR! network This is a problem related to network connectivity.\n'
    'npm ERR! A complete log of this run can be found in:\n'
    'npm ERR!   /srv/invented/hermes/home/.npm/_logs/2000-01-01T00_00_00_000Z-debug-0.log';
const _exited = 'WhatsApp pairing process exited with code 1.';
// A right-to-left override, a bell and a zero-width space: shown as marks.
final _controls =
    'WhatsApp pairing process exited${_chars([0x202E])}gnp.${_chars([0x202C])} with code 1.${_chars([0x07, 0x200B])}';
const _refusedText = "WhatsApp mode must be 'bot' or 'self-chat'.";

/// Control and bidi characters, made at run time so no tool normalises them
/// in the source.
String _chars(List<int> codes) => String.fromCharCodes(codes);

void _noop() {}

Widget _at(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

/// The Material look whatever the viewport's platform.
Widget _material(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.android),
    child: child,
  ),
);

bool _isHandset(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < 600;

/// A widget in the grouped list's width, as the page holds it.
Widget _list(Widget child) =>
    GroupedListView(children: [const SizedBox(height: 8), child]);

WidgetbookUseCase _case(String name, Widget Function() child) =>
    WidgetbookUseCase(name: name, builder: (_) => child());

/// The extra looks of a state: its largest text, German, and German at the
/// largest text.
List<WidgetbookUseCase> _looks(String name, Widget Function() child) => [
  WidgetbookUseCase(
    name: '$name, largest text',
    builder: (_) => _at(3, child()),
  ),
  WidgetbookUseCase(name: '$name, German', builder: (_) => _german(child())),
  WidgetbookUseCase(
    name: '$name, German, largest text',
    builder: (_) => _german(_at(3, child())),
  ),
];

/// Owns the numbers field and the mode, so typing and choosing work.
class _FormHost extends StatefulWidget {
  const _FormHost({required this.builder, this.text = '', this.mode});

  final Widget Function(
    BuildContext context,
    TextEditingController numbers,
    WhatsAppMode mode,
    ValueChanged<WhatsAppMode> onMode,
  )
  builder;
  final String text;
  final WhatsAppMode? mode;

  @override
  State<_FormHost> createState() => _FormHostState();
}

class _FormHostState extends State<_FormHost> {
  late final _numbers = TextEditingController(text: widget.text);
  late var _mode = widget.mode ?? WhatsAppMode.bot;

  @override
  void dispose() {
    _numbers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _numbers,
    _mode,
    (mode) => setState(() => _mode = mode),
  );
}

Widget _form({
  String text = '',
  WhatsAppMode? mode,
  WhatsAppNumbersIssue? issue,
  WhatsAppStartProblem? problem,
  String? serverText,
  bool starting = false,
  bool? handset,
}) => _FormHost(
  text: text,
  mode: mode,
  builder: (context, numbers, current, onMode) => _list(
    WhatsAppSetupForm(
      mode: current,
      onModeChanged: onMode,
      numbers: numbers,
      numbersIssue: issue,
      problem: problem,
      serverText: serverText,
      starting: starting,
      onStart: _noop,
      onStartAgain: _noop,
      handset: handset ?? _isHandset(context),
    ),
  ),
);

/// The screen's body in one state, pushed over another route so it has the
/// back button the screen has. A sketch for looking at states; the screen
/// itself comes later. Phone-sized windows are handsets, like the app.
Widget _page({
  required WhatsAppViewPhase phase,
  String text = '',
  WhatsAppMode? mode,
  WhatsAppNumbersIssue? issue,
  WhatsAppStartProblem? startProblem,
  String? serverText,
  WhatsAppWorkStage stage = WhatsAppWorkStage.starting,
  QrCodeVisibility visibility = QrCodeVisibility.shown,
  Duration? timeLeft = _timeLeft,
  bool paused = false,
  bool offline = false,
  bool alreadyLinked = false,
  String? name = _name,
  String? phone = _phone,
  bool selfChatBlank = false,
  WhatsAppFinishStatus finish = WhatsAppFinishStatus.idle,
  bool refreshing = false,
  bool refreshFailed = false,
  bool goneDuringApply = false,
  bool? handset,
}) => pushed(
  _FormHost(
    text: text,
    mode: mode,
    builder: (context, numbers, current, onMode) => Scaffold(
      appBar: AppBar(
        leading: const AdaptiveBackButton(previousTitle: 'Messaging'),
        leadingWidth: adaptiveBackLeadingWidth(context),
        title: Text(context.l10n.messagingWhatsappTitle),
      ),
      body: WhatsAppPairingView(
        phase: phase,
        handset: handset ?? _isHandset(context),
        mode: current,
        numbers: numbers,
        numbersIssue: issue,
        startProblem: startProblem,
        serverText: serverText,
        workStage: stage,
        codeVisibility: visibility,
        qrPayload: _payload,
        timeLeft: timeLeft,
        paused: paused,
        offline: offline,
        alreadyLinked: alreadyLinked,
        accountName: name,
        accountPhone: phone,
        profile: _profile,
        selfChatBlankNumbers: selfChatBlank,
        finish: finish,
        refreshing: refreshing,
        refreshFailed: refreshFailed,
        goneDuringApply: goneDuringApply,
        onModeChanged: onMode,
        onStart: _noop,
        onStartAgain: _noop,
        onCancel: _noop,
        onShowQr: _noop,
        onFinish: _noop,
        onCheck: _noop,
        onBack: _noop,
      ),
    ),
  ),
);

/// A page state in four looks: as it is, largest text, German, German at the
/// largest text.
List<WidgetbookUseCase> _pageCases(String name, Widget Function() page) => [
  _case(name, page),
  ..._looks(name, page),
];

/// Opens [open] once the use case is on screen, over a stand-in for the screen
/// the question comes from.
WidgetbookUseCase _question(
  String name,
  Future<void> Function(BuildContext context) open, {
  bool android = false,
  bool german = false,
  double scale = 1,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) {
    Widget child = openOnShow(open);
    if (scale != 1) child = _at(scale, child);
    if (german) child = _german(child);
    if (android) child = _material(child);
    return child;
  },
);

const _platformRows = [
  HermesMessagingPlatform(
    id: 'whatsapp',
    name: 'WhatsApp',
    description: 'Chat with Hermes on WhatsApp.',
    enabled: true,
    configured: true,
  ),
  HermesMessagingPlatform(
    id: 'telegram',
    name: 'Telegram',
    description: 'Run Hermes from Telegram.',
    enabled: true,
    configured: true,
  ),
];

/// The Messaging list under its banner, as it looks after Finish closed the
/// screens.
Widget _messagingList(Widget banner) => Scaffold(
  appBar: AppBar(title: const Text('Messaging')),
  body: Builder(
    builder: (context) => GroupedListView(
      children: [
        Padding(padding: const EdgeInsets.only(top: 8), child: banner),
        GroupedSection(
          dividerIndent: GroupedMetrics.of(context).indentAfterTile,
          children: [
            for (final platform in _platformRows)
              MessagingPlatformRow(
                platform: platform,
                onSetUp: _noop,
                onToggle: (_) {},
              ),
          ],
        ),
      ],
    ),
  ),
);

Widget _savedBanner(
  WhatsAppSavedKind kind, {
  String? error,
  bool server = true,
}) => _messagingList(
  WhatsAppSavedBanner(
    kind: kind,
    restartError: error,
    onOpenServer: server ? _noop : null,
    onClose: _noop,
  ),
);

Widget _end(
  PairingEndKind kind, {
  String? text,
  bool duringApply = false,
  bool? handset,
}) => Builder(
  builder: (context) => frame(
    PairingEnd(
      kind: kind,
      serverText: text,
      duringApply: duringApply,
      handset: handset ?? _isHandset(context),
      onStartAgain: _noop,
      onBack: _noop,
    ),
    maxWidth: 560,
  ),
);

Widget _card(Widget Function(bool handset) child, {double maxWidth = 480}) =>
    Builder(
      builder: (context) =>
          frame(child(_isHandset(context)), maxWidth: maxWidth),
    );

Widget _tile(
  QrCodeVisibility visibility, {
  double size = kQrTileSize,
  String payload = _payload,
}) => frame(
  Center(
    child: QrCodeTile(
      visibility: visibility,
      payload: payload,
      onShow: _noop,
      size: size,
    ),
  ),
  maxWidth: 360,
);

Widget _qrCard(QrCodeVisibility visibility, {Duration? timeLeft = _timeLeft}) =>
    frame(
      QrCodeCard(
        visibility: visibility,
        payload: _payload,
        timeLeft: timeLeft,
        onShow: _noop,
      ),
      maxWidth: 360,
    );

WidgetbookNode whatsappNode() => WidgetbookFolder(
  name: 'WhatsApp link',
  children: [
    WidgetbookComponent(
      name: 'WhatsAppSetupForm',
      useCases: [
        _case('Empty (Bot)', _form),
        ...onEachPlatform('Empty', (_) => _form()),
        _case(
          'Self-chat, with numbers',
          () => _form(mode: WhatsAppMode.selfChat, text: _numbersText),
        ),
        _case(
          'Invalid number',
          () => _form(
            text: '+1 555 abc',
            issue: WhatsAppNumbersIssue.notPhoneNumber,
          ),
        ),
        _case(
          'Everyone is a server setting',
          () => _form(text: '*', issue: WhatsAppNumbersIssue.everyone),
        ),
        _case('Starting', () => _form(text: _numbersText, starting: true)),
        _case(
          'Refused by the server',
          () => _form(
            text: _numbersText,
            problem: WhatsAppStartProblem.refused,
            serverText: _refusedText,
          ),
        ),
        _case(
          'Offline',
          () =>
              _form(text: _numbersText, problem: WhatsAppStartProblem.offline),
        ),
        _case(
          'Lost answer',
          () => _form(
            text: _numbersText,
            problem: WhatsAppStartProblem.lostAnswer,
          ),
        ),
        _case('Tablet, not a handset', () => _form(handset: false)),
        _case('Material', () => _material(_form(text: _numbersText))),
        _case(
          'Material, invalid number',
          () => _material(
            _form(text: 'call me', issue: WhatsAppNumbersIssue.notPhoneNumber),
          ),
        ),
        ..._looks(
          'Invalid number',
          () => _form(
            text: '+1 555 abc',
            issue: WhatsAppNumbersIssue.notPhoneNumber,
          ),
        ),
        ..._looks('Empty', _form),
        ..._looks(
          'Lost answer',
          () => _form(
            text: _numbersText,
            problem: WhatsAppStartProblem.lostAnswer,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'PairingStageCard',
      useCases: [
        for (final (name, stage) in [
          ('Installing', WhatsAppWorkStage.installing),
          ('Starting', WhatsAppWorkStage.starting),
          ('Working (unknown status)', WhatsAppWorkStage.other),
        ])
          _case(
            name,
            () => _card(
              (h) =>
                  PairingStageCard(stage: stage, handset: h, onCancel: _noop),
            ),
          ),
        ..._looks(
          'Installing',
          () => _card(
            (h) => PairingStageCard(
              stage: WhatsAppWorkStage.installing,
              handset: h,
              onCancel: _noop,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'HandsetQrNotice',
      useCases: [
        _case(
          'Before the tap',
          () => frame(HandsetQrNotice(revealed: false, onShow: _noop)),
        ),
        _case(
          'After the tap',
          () => frame(HandsetQrNotice(revealed: true, onShow: _noop)),
        ),
        ..._looks(
          'Before the tap',
          () => frame(HandsetQrNotice(revealed: false, onShow: _noop)),
        ),
        ..._looks(
          'After the tap',
          () => frame(HandsetQrNotice(revealed: true, onShow: _noop)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'QrCodeTile',
      useCases: [
        _case('Shown', () => _tile(QrCodeVisibility.shown)),
        _case(
          'Shown, a rotated code',
          () => _tile(
            QrCodeVisibility.shown,
            payload: 'DEMO-NOT-A-REAL-QR,2@invented-segment-one-0007,rotated=',
          ),
        ),
        _case('Shown, wide layout (280)', () {
          return _tile(QrCodeVisibility.shown, size: kQrTileSizeWide);
        }),
        _case(
          'Hidden (tablet or computer)',
          () => _tile(QrCodeVisibility.hidden),
        ),
        _case(
          'Hidden, needs a tap (handset)',
          () => _tile(QrCodeVisibility.needsTap),
        ),
        _case(
          'Too long to draw',
          () => _tile(
            QrCodeVisibility.shown,
            payload: 'DEMO-NOT-A-REAL-QR-' * 400,
          ),
        ),
        _case(
          'Material, shown',
          () => _material(_tile(QrCodeVisibility.shown)),
        ),
        ..._looks('Hidden', () => _tile(QrCodeVisibility.hidden)),
        ..._looks('Needs a tap', () => _tile(QrCodeVisibility.needsTap)),
      ],
    ),
    WidgetbookComponent(
      name: 'QrCodeCard',
      useCases: [
        _case(
          'Shown, setup closes in 8:42',
          () => _qrCard(QrCodeVisibility.shown),
        ),
        _case(
          'Shown, expiring (last minute)',
          () => _qrCard(QrCodeVisibility.shown, timeLeft: _expiring),
        ),
        _case(
          'Hidden (tablet or computer)',
          () => _qrCard(QrCodeVisibility.hidden),
        ),
        _case(
          'Needs a tap (handset)',
          () => _qrCard(QrCodeVisibility.needsTap),
        ),
        _case(
          'No countdown yet',
          () => _qrCard(QrCodeVisibility.shown, timeLeft: null),
        ),
        ..._looks('Shown', () => _qrCard(QrCodeVisibility.shown)),
        ..._looks(
          'Expiring',
          () => _qrCard(QrCodeVisibility.shown, timeLeft: _expiring),
        ),
        ..._looks('Hidden', () => _qrCard(QrCodeVisibility.hidden)),
      ],
    ),
    WidgetbookComponent(
      name: 'ScanSteps',
      useCases: [
        _case('Steps', () => frame(const ScanSteps())),
        ..._looks('Steps', () => frame(const ScanSteps())),
      ],
    ),
    WidgetbookComponent(
      name: 'LinkedAccountCard',
      useCases: [
        _case(
          'New account',
          () => _list(
            const LinkedAccountCard(
              alreadyLinked: false,
              name: _name,
              phone: _phone,
            ),
          ),
        ),
        _case(
          'Already linked',
          () => _list(
            const LinkedAccountCard(
              alreadyLinked: true,
              name: _name,
              phone: _phone,
            ),
          ),
        ),
        _case(
          'Long name',
          () => _list(
            const LinkedAccountCard(
              alreadyLinked: false,
              name: _longName,
              phone: _phone,
            ),
          ),
        ),
        _case(
          'Name and number not given',
          () => _list(const LinkedAccountCard(alreadyLinked: false)),
        ),
        _case(
          'Control characters in the name',
          () => _list(
            LinkedAccountCard(
              alreadyLinked: false,
              name: 'Mara${_chars([0x202E])} Example${_chars([0x200B])}',
              phone: _phone,
            ),
          ),
        ),
        ..._looks(
          'New account',
          () => _list(
            const LinkedAccountCard(
              alreadyLinked: false,
              name: _name,
              phone: _phone,
            ),
          ),
        ),
        ..._looks(
          'Already linked, long name',
          () => _list(
            const LinkedAccountCard(
              alreadyLinked: true,
              name: _longName,
              phone: _phone,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'PairingEnd',
      useCases: [
        _case(
          'Error, the server\'s text',
          () => _end(PairingEndKind.error, text: _exited),
        ),
        _case(
          'Error, ten lines of log',
          () => _end(PairingEndKind.error, text: _installFailed),
        ),
        _case(
          'Error, control characters shown',
          () => _end(PairingEndKind.error, text: _controls),
        ),
        _case('Error, no text', () => _end(PairingEndKind.error)),
        _case('Expired', () => _end(PairingEndKind.expired)),
        _case('Superseded', () => _end(PairingEndKind.superseded)),
        _case('Gone', () => _end(PairingEndKind.gone)),
        _case(
          'Gone while saving',
          () => _end(PairingEndKind.gone, duringApply: true),
        ),
        _case('Old server', () => _end(PairingEndKind.unsupported)),
        _case('Profile deleted', () => _end(PairingEndKind.profileDeleted)),
        _case(
          'Tablet, not a handset',
          () => _end(PairingEndKind.expired, handset: false),
        ),
        _case(
          'Material',
          () => _material(_end(PairingEndKind.error, text: _exited)),
        ),
        ..._looks(
          'Error',
          () => _end(PairingEndKind.error, text: _installFailed),
        ),
        ..._looks(
          'Gone while saving',
          () => _end(PairingEndKind.gone, duringApply: true),
        ),
        ..._looks('Old server', () => _end(PairingEndKind.unsupported)),
      ],
    ),
    WidgetbookComponent(
      name: 'Finish question',
      useCases: [
        _question('iPhone', askFinishWhatsApp),
        _question('Android', askFinishWhatsApp, android: true),
        _question('German (iPhone)', askFinishWhatsApp, german: true),
        _question(
          'German (Android)',
          askFinishWhatsApp,
          android: true,
          german: true,
        ),
        _question('Largest text (iPhone)', askFinishWhatsApp, scale: 3),
        _question(
          'Largest text (Android)',
          askFinishWhatsApp,
          android: true,
          scale: 3,
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'WhatsAppSavedBanner',
      useCases: [
        _case(
          'Restart requested',
          () => _savedBanner(WhatsAppSavedKind.restartRequested),
        ),
        _case(
          'No restart requested',
          () => _savedBanner(WhatsAppSavedKind.noRestart),
        ),
        _case(
          'Restart may still be needed',
          () => _savedBanner(WhatsAppSavedKind.restartMayBeNeeded),
        ),
        _case(
          'Saved, restart not known (after Check)',
          () => _savedBanner(WhatsAppSavedKind.unknownRestart),
        ),
        _case(
          'With the restart error',
          () => _savedBanner(
            WhatsAppSavedKind.noRestart,
            error: "Could not run 'hermes gateway restart'.",
          ),
        ),
        _case(
          'Without Open Server',
          () => _savedBanner(WhatsAppSavedKind.noRestart, server: false),
        ),
        ..._looks(
          'No restart requested',
          () => _savedBanner(WhatsAppSavedKind.noRestart),
        ),
        ..._looks(
          'Restart requested',
          () => _savedBanner(WhatsAppSavedKind.restartRequested),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'WhatsAppPairingView (page states)',
      useCases: [
        ..._pageCases('A. Setup', () => _page(phase: WhatsAppViewPhase.setup)),
        _case(
          'A. Setup, invalid number',
          () => _page(
            phase: WhatsAppViewPhase.setup,
            text: '+1 555 abc',
            issue: WhatsAppNumbersIssue.notPhoneNumber,
          ),
        ),
        _case(
          'A. Starting',
          () => _page(phase: WhatsAppViewPhase.starting, text: _numbersText),
        ),
        _case(
          'A. Server refused',
          () => _page(
            phase: WhatsAppViewPhase.setup,
            text: _numbersText,
            startProblem: WhatsAppStartProblem.refused,
            serverText: _refusedText,
          ),
        ),
        _case(
          'A. Offline',
          () => _page(
            phase: WhatsAppViewPhase.setup,
            text: _numbersText,
            startProblem: WhatsAppStartProblem.offline,
          ),
        ),
        ..._pageCases(
          'A. Lost answer',
          () => _page(phase: WhatsAppViewPhase.startLost, text: _numbersText),
        ),
        ..._pageCases(
          'B. Installing',
          () => _page(
            phase: WhatsAppViewPhase.working,
            stage: WhatsAppWorkStage.installing,
          ),
        ),
        _case('B. Starting', () => _page(phase: WhatsAppViewPhase.working)),
        _case(
          'B. Working (unknown status)',
          () => _page(
            phase: WhatsAppViewPhase.working,
            stage: WhatsAppWorkStage.other,
          ),
        ),
        _case(
          'B. Offline',
          () => _page(
            phase: WhatsAppViewPhase.working,
            stage: WhatsAppWorkStage.installing,
            offline: true,
          ),
        ),
        _case(
          'B. Paused',
          () => _page(phase: WhatsAppViewPhase.working, paused: true),
        ),
        ..._pageCases(
          'C. Handset, before the tap',
          () => _page(
            phase: WhatsAppViewPhase.waiting,
            visibility: QrCodeVisibility.needsTap,
            handset: true,
          ),
        ),
        _case(
          'C. Handset, after the tap',
          () => _page(phase: WhatsAppViewPhase.waiting, handset: true),
        ),
        ..._pageCases(
          'D. QR shown',
          () => _page(phase: WhatsAppViewPhase.waiting),
        ),
        _case(
          'D. QR on a tablet in a narrow window (not a handset)',
          () => _page(phase: WhatsAppViewPhase.waiting, handset: false),
        ),
        _case(
          'D. QR hidden (tablet or computer)',
          () => _page(
            phase: WhatsAppViewPhase.waiting,
            visibility: QrCodeVisibility.hidden,
            handset: false,
          ),
        ),
        _case(
          'D. QR hidden, needs a tap (tablet or computer)',
          () => _page(
            phase: WhatsAppViewPhase.waiting,
            visibility: QrCodeVisibility.needsTap,
            handset: false,
          ),
        ),
        ..._pageCases(
          'D. QR expiring',
          () => _page(phase: WhatsAppViewPhase.waiting, timeLeft: _expiring),
        ),
        _case(
          'D. QR offline',
          () => _page(phase: WhatsAppViewPhase.waiting, offline: true),
        ),
        _case(
          'D. QR paused',
          () => _page(phase: WhatsAppViewPhase.waiting, paused: true),
        ),
        _case(
          'D. QR, handset hidden by a lock',
          () => _page(
            phase: WhatsAppViewPhase.waiting,
            visibility: QrCodeVisibility.hidden,
            handset: true,
            paused: true,
          ),
        ),
        ..._pageCases(
          'E. Linked',
          () => _page(phase: WhatsAppViewPhase.connected),
        ),
        ..._pageCases(
          'E. Already linked',
          () => _page(phase: WhatsAppViewPhase.connected, alreadyLinked: true),
        ),
        _case(
          'E. Linked, Self-chat with a blank list',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            mode: WhatsAppMode.selfChat,
            selfChatBlank: true,
          ),
        ),
        _case(
          'E. Linked, long name',
          () => _page(phase: WhatsAppViewPhase.connected, name: _longName),
        ),
        _case(
          'E. Linked, name and number not given',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            name: null,
            phone: null,
          ),
        ),
        _case(
          'E. Reading the account again',
          () => _page(phase: WhatsAppViewPhase.connected, refreshing: true),
        ),
        _case(
          'E. Reading the account failed',
          () => _page(phase: WhatsAppViewPhase.connected, refreshFailed: true),
        ),
        _case(
          'G. Saving',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            finish: WhatsAppFinishStatus.applying,
          ),
        ),
        _case(
          'G. Refused',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            finish: WhatsAppFinishStatus.refused,
            serverText: 'Failed to save WhatsApp setup.',
          ),
        ),
        ..._pageCases(
          'G. Lost answer, Check',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            finish: WhatsAppFinishStatus.lostAnswer,
          ),
        ),
        _case(
          'G. Checking',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            finish: WhatsAppFinishStatus.checking,
          ),
        ),
        _case(
          'G. Check could not confirm',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            finish: WhatsAppFinishStatus.checkFailed,
          ),
        ),
        _case(
          'G. Not saved yet',
          () => _page(
            phase: WhatsAppViewPhase.connected,
            finish: WhatsAppFinishStatus.notSavedYet,
          ),
        ),
        _case(
          'G. Setup gone while saving',
          () => _page(phase: WhatsAppViewPhase.gone, goneDuringApply: true),
        ),
        ..._pageCases(
          'F. Error, the server\'s text',
          () => _page(
            phase: WhatsAppViewPhase.failed,
            serverText: _installFailed,
          ),
        ),
        _case(
          'F. Error, control characters',
          () => _page(phase: WhatsAppViewPhase.failed, serverText: _controls),
        ),
        _case('F. Expired', () => _page(phase: WhatsAppViewPhase.expired)),
        _case(
          'F. Superseded',
          () => _page(phase: WhatsAppViewPhase.superseded),
        ),
        _case('F. Gone', () => _page(phase: WhatsAppViewPhase.gone)),
        _case(
          'F. Old server',
          () => _page(phase: WhatsAppViewPhase.unsupported),
        ),
        _case(
          'F. Profile deleted',
          () => _page(phase: WhatsAppViewPhase.profileDeleted),
        ),
        _case(
          'Material, setup',
          () => _material(_page(phase: WhatsAppViewPhase.setup)),
        ),
        _case(
          'Material, QR shown',
          () => _material(_page(phase: WhatsAppViewPhase.waiting)),
        ),
        _case(
          'Material, linked',
          () => _material(_page(phase: WhatsAppViewPhase.connected)),
        ),
      ],
    ),
  ],
);
