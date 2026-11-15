import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/motion_spinner.dart';
import '../whatsapp/whatsapp_pairing.dart';
import 'handset_qr_notice.dart';
import 'linked_account_card.dart';
import 'pairing_buttons.dart';
import 'pairing_end.dart';
import 'pairing_stage_card.dart';
import 'qr_code_card.dart';
import 'scan_steps.dart';
import 'whatsapp_setup_form.dart';

/// Where the pairing screen's body stands.
enum WhatsAppViewPhase {
  /// The form. Nothing has been sent.
  setup,

  /// The start request is out.
  starting,

  /// A start with no answer: the form with "Start again".
  startLost,

  /// The server installs or starts; see [WhatsAppPairingView.workStage].
  working,

  /// A code to scan, or its stand-in; see [WhatsAppPairingView.codeVisibility].
  waiting,

  /// Linked, with Finish and its outcomes.
  connected,

  /// The server's own error text.
  failed,
  expired,
  superseded,
  gone,
  unsupported,
  profileDeleted,
}

/// How Finish stands in [WhatsAppViewPhase.connected].
enum WhatsAppFinishStatus {
  /// Finish is offered.
  idle,

  /// The apply is out: "Saving...".
  applying,

  /// The server refused: its text in an error banner; Finish is offered again.
  refused,

  /// No answer: "Could not confirm the setup was saved." with Check, and no
  /// Finish.
  lostAnswer,

  /// A Check read is out.
  checking,

  /// Check could not tell: "Couldn't confirm. Try again." with Check.
  checkFailed,

  /// Check found WhatsApp off: "Not saved yet." with Start again.
  notSavedYet,
}

/// The body of the "Link WhatsApp" screen for every phase, over plain values
/// and callbacks, so the screen holds only the controller. It places the
/// widgets of this folder: [WhatsAppSetupForm], [PairingStageCard],
/// [HandsetQrNotice], [QrCodeTile] with [QrScanStatus], [ScanSteps],
/// [LinkedAccountCard] and [PairingEnd], plus the "Paused" and offline notes
/// and the Finish section. One filled button per state; Cancel is outlined.
///
/// The QR payload is read only when [codeVisibility] is shown (it is dropped
/// otherwise) and goes into the tile alone. At a content width of 640 or more
/// (a tablet or a computer) the code phase is two columns, the tile left and
/// the status, countdown, steps and Cancel right, unless the text size is 2 or
/// more.
class WhatsAppPairingView extends StatelessWidget {
  const WhatsAppPairingView({
    super.key,
    required this.phase,
    this.handset = true,
    required this.mode,
    required this.numbers,
    this.numbersIssue,
    this.startProblem,
    this.serverText,
    this.workStage = WhatsAppWorkStage.starting,
    this.codeVisibility = QrCodeVisibility.hidden,
    String? qrPayload,
    this.timeLeft,
    this.paused = false,
    this.offline = false,
    this.alreadyLinked = false,
    this.accountName,
    this.accountPhone,
    this.profile = '',
    this.selfChatBlankNumbers = false,
    this.finish = WhatsAppFinishStatus.idle,
    this.refreshing = false,
    this.refreshFailed = false,
    this.goneDuringApply = false,
    this.onModeChanged,
    this.onNumbersChanged,
    this.onStart,
    this.onStartAgain,
    this.onCancel,
    this.onShowQr,
    this.onFinish,
    this.onCheck,
    this.onBack,
  }) : qrPayload = codeVisibility == QrCodeVisibility.shown ? qrPayload : null;

  final WhatsAppViewPhase phase;

  /// A phone (shortest side under 600 dp): buttons are full width and the code
  /// waits for a tap.
  final bool handset;

  // The form.
  final WhatsAppMode mode;
  final TextEditingController numbers;
  final WhatsAppNumbersIssue? numbersIssue;
  final WhatsAppStartProblem? startProblem;

  /// The server's text for a refused start, a refused apply or an error end.
  /// Display only.
  final String? serverText;

  // Preparing and the code.
  final WhatsAppWorkStage workStage;
  final QrCodeVisibility codeVisibility;

  /// The code's text; null unless [codeVisibility] is shown.
  final String? qrPayload;
  final Duration? timeLeft;

  /// Polling was paused and is resuming; goes with the next answer.
  final bool paused;

  /// The last poll got no answer.
  final bool offline;

  // Linked.
  final bool alreadyLinked;
  final String? accountName;
  final String? accountPhone;

  /// The profile the setup is saved for, shown in "What Finish does".
  final String profile;

  /// Self-chat with a blank list: "Allowed: your own number."
  final bool selfChatBlankNumbers;
  final WhatsAppFinishStatus finish;

  /// The account was dropped by App Lock and is being read again.
  final bool refreshing;

  /// That read failed again and again.
  final bool refreshFailed;

  /// For [WhatsAppViewPhase.gone]: found while saving.
  final bool goneDuringApply;

  final ValueChanged<WhatsAppMode>? onModeChanged;
  final ValueChanged<String>? onNumbersChanged;
  final VoidCallback? onStart;
  final VoidCallback? onStartAgain;
  final VoidCallback? onCancel;
  final VoidCallback? onShowQr;
  final VoidCallback? onFinish;
  final VoidCallback? onCheck;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide =
          box.maxWidth >= 640 &&
          MediaQuery.textScalerOf(context).scale(14) < 28;
      return GroupedListView(children: _children(context, wide));
    },
  );

  List<Widget> _children(BuildContext context, bool wide) {
    final top = _note(context);
    final body = switch (phase) {
      WhatsAppViewPhase.setup ||
      WhatsAppViewPhase.starting ||
      WhatsAppViewPhase.startLost => [_form()],
      WhatsAppViewPhase.working => [
        PairingStageCard(
          stage: workStage,
          onCancel: onCancel ?? _noop,
          handset: handset,
        ),
      ],
      WhatsAppViewPhase.waiting => _code(context, wide),
      WhatsAppViewPhase.connected => _linked(context),
      WhatsAppViewPhase.failed => [_end(PairingEndKind.error)],
      WhatsAppViewPhase.expired => [_end(PairingEndKind.expired)],
      WhatsAppViewPhase.superseded => [_end(PairingEndKind.superseded)],
      WhatsAppViewPhase.gone => [_end(PairingEndKind.gone)],
      WhatsAppViewPhase.unsupported => [_end(PairingEndKind.unsupported)],
      WhatsAppViewPhase.profileDeleted => [_end(PairingEndKind.profileDeleted)],
    };
    return [
      const SizedBox(height: 8),
      ?top,
      if (top != null) const SizedBox(height: 12),
      ...body,
    ];
  }

  static void _noop() {}

  Widget _form() => WhatsAppSetupForm(
    mode: mode,
    onModeChanged: onModeChanged ?? (_) {},
    numbers: numbers,
    numbersIssue: numbersIssue,
    onNumbersChanged: onNumbersChanged,
    problem: phase == WhatsAppViewPhase.startLost
        ? WhatsAppStartProblem.lostAnswer
        : startProblem,
    serverText: serverText,
    starting: phase == WhatsAppViewPhase.starting,
    onStart: onStart,
    onStartAgain: onStartAgain,
    handset: handset,
  );

  PairingEnd _end(PairingEndKind kind) => PairingEnd(
    kind: kind,
    serverText: serverText,
    duringApply: goneDuringApply,
    handset: handset,
    onStartAgain: onStartAgain,
    onBack: onBack,
  );

  /// The offline note replaces the paused one: if the poll that follows a
  /// pause fails, the banner says so.
  Widget? _note(BuildContext context) {
    final l10n = context.l10n;
    final polling =
        phase == WhatsAppViewPhase.working ||
        phase == WhatsAppViewPhase.waiting;
    if (!polling) return null;
    if (offline) {
      return AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.messagingWhatsappOfflineTitle,
        detail: phase == WhatsAppViewPhase.waiting
            ? l10n.messagingWhatsappOfflineCode
            : l10n.messagingWhatsappOfflineChecking,
      );
    }
    if (paused) {
      return AppBanner(
        tone: AppBannerTone.neutral,
        icon: AppIcons.pause,
        title: l10n.messagingWhatsappPausedTitle,
        detail: l10n.messagingWhatsappPausedDetail,
      );
    }
    return null;
  }

  List<Widget> _code(BuildContext context, bool wide) {
    final l10n = context.l10n;
    final cancel = PairingActions(
      handset: handset,
      children: [
        PairingButton.outlined(
          label: l10n.messagingWhatsappCancelSetup,
          onPressed: onCancel,
        ),
      ],
    );
    // A phone shows the notice, and no code, until the tap.
    if (handset && codeVisibility != QrCodeVisibility.shown) {
      return [
        HandsetQrNotice(revealed: false, onShow: onShowQr ?? _noop),
        const SizedBox(height: 12),
        cancel,
      ];
    }
    final size = wide ? kQrTileSizeWide : kQrTileSize;
    final tile = QrCodeTile(
      visibility: codeVisibility,
      payload: qrPayload,
      onShow: onShowQr,
      size: size,
    );
    final status = QrScanStatus(timeLeft: timeLeft);
    final steps = const ScanSteps();
    if (wide) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile,
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [status, steps, cancel],
              ),
            ),
          ],
        ),
      ];
    }
    return [
      if (handset) ...[
        HandsetQrNotice(revealed: true, onShow: onShowQr ?? _noop),
        const SizedBox(height: 12),
      ],
      Center(child: tile),
      const SizedBox(height: 16),
      status,
      const SizedBox(height: 16),
      steps,
      const SizedBox(height: 20),
      cancel,
    ];
  }

  List<Widget> _linked(BuildContext context) {
    final l10n = context.l10n;
    if (refreshing) {
      return [
        Row(
          spacing: 10,
          children: [
            const MotionSpinner(),
            Expanded(child: Text(l10n.messagingWhatsappRefreshingAccount)),
          ],
        ),
      ];
    }
    if (refreshFailed) {
      return [
        AppBanner(
          tone: AppBannerTone.warning,
          title: l10n.messagingWhatsappRefreshFailedTitle,
          detail: l10n.messagingWhatsappRefreshFailedDetail,
          action: PairingButton.filled(
            label: l10n.messagingWhatsappStartAgain,
            onPressed: onStartAgain,
          ),
        ),
      ];
    }
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final scheme = Theme.of(context).colorScheme;
    final status = _finishStatus(context);
    final canFinish =
        finish == WhatsAppFinishStatus.idle ||
        finish == WhatsAppFinishStatus.applying ||
        finish == WhatsAppFinishStatus.refused;
    final footer = [
      l10n.messagingWhatsappFinishFooter(profile),
      if (selfChatBlankNumbers) l10n.messagingWhatsappFinishOwnNumber,
    ].join(' ');
    return [
      ?status,
      if (status != null) const SizedBox(height: 12),
      LinkedAccountCard(
        alreadyLinked: alreadyLinked,
        name: accountName,
        phone: accountPhone,
      ),
      Padding(
        padding: EdgeInsets.only(top: metrics.sectionGap),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Semantics(
                header: true,
                child: Text(
                  metrics.headerUppercase
                      ? l10n.messagingWhatsappFinishHeader.toUpperCase()
                      : l10n.messagingWhatsappFinishHeader,
                  style: TextStyle(
                    fontSize: metrics.headerSize,
                    fontWeight: metrics.headerWeight,
                    color: muted,
                  ),
                ),
              ),
              Text(
                footer,
                style: TextStyle(
                  fontSize: metrics.subtitleSize,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (canFinish)
        PairingActions(
          handset: handset,
          children: [
            PairingButton.filled(
              label: finish == WhatsAppFinishStatus.applying
                  ? l10n.messagingWhatsappSaving
                  : l10n.messagingWhatsappFinish,
              busy: finish == WhatsAppFinishStatus.applying,
              onPressed: onFinish,
            ),
          ],
        ),
      Padding(
        padding: EdgeInsets.only(top: canFinish ? 12 : 0),
        child: Text(
          l10n.messagingWhatsappFinishLeaveNote,
          style: TextStyle(fontSize: metrics.footerSize, color: muted),
        ),
      ),
    ];
  }

  Widget? _finishStatus(BuildContext context) {
    final l10n = context.l10n;
    Widget check({bool busy = false}) => PairingButton.filled(
      label: busy
          ? l10n.messagingWhatsappChecking
          : l10n.messagingWhatsappCheck,
      busy: busy,
      onPressed: onCheck,
    );
    return switch (finish) {
      WhatsAppFinishStatus.idle || WhatsAppFinishStatus.applying => null,
      WhatsAppFinishStatus.refused => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.messagingWhatsappFinishRefusedTitle,
        detail: serverText == null ? '' : whatsAppSafeServerText(serverText!),
      ),
      WhatsAppFinishStatus.lostAnswer => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.messagingWhatsappFinishLostTitle,
        detail: l10n.messagingWhatsappFinishLostDetail,
        action: check(),
      ),
      WhatsAppFinishStatus.checking => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.messagingWhatsappFinishLostTitle,
        detail: l10n.messagingWhatsappFinishLostDetail,
        action: check(busy: true),
      ),
      WhatsAppFinishStatus.checkFailed => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.messagingWhatsappCheckFailedTitle,
        action: check(),
      ),
      WhatsAppFinishStatus.notSavedYet => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.messagingWhatsappNotSavedTitle,
        action: PairingButton.filled(
          label: l10n.messagingWhatsappStartAgain,
          onPressed: onStartAgain,
        ),
      ),
    };
  }
}
