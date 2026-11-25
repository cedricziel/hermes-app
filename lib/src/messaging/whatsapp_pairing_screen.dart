import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../app_lock/app_lock_controller.dart';
import '../widgets/adaptive_back_button.dart';
import '../widgets/content_column.dart';
import '../widgets/route_dismissal.dart';
import 'hermes_messaging_repository.dart';
import 'whatsapp/whatsapp_pairing.dart';
import 'whatsapp/whatsapp_pairing_controller.dart';
import 'whatsapp/whatsapp_pairing_telemetry.dart';
import 'widgets/qr_code_card.dart';
import 'widgets/whatsapp_finish_question.dart';
import 'widgets/whatsapp_pairing_view.dart';
import 'widgets/whatsapp_saved_banner.dart';
import 'widgets/whatsapp_setup_form.dart';

/// The shortest side under which a device is a handset: it cannot scan its own
/// screen, so the code waits for a tap.
const double kWhatsAppHandsetShortestSide = 600;

/// What the WhatsApp screen hands back once the setup is saved: how the
/// Messaging list words the banner. The restart error is the server's own
/// text, shown as given on that banner only.
class WhatsAppSavedOutcome {
  const WhatsAppSavedOutcome(this.kind, {this.restartError});

  final WhatsAppSavedKind kind;
  final String? restartError;

  /// `Check` found WhatsApp on where it was off before Finish was sent: the
  /// save happened, and whether a restart did is not known.
  const WhatsAppSavedOutcome.checked() : this(WhatsAppSavedKind.unknownRestart);

  factory WhatsAppSavedOutcome.fromApply(WhatsAppApplyResult result) =>
      WhatsAppSavedOutcome(
        result.restartStarted
            ? (result.needsRestart
                  ? WhatsAppSavedKind.restartMayBeNeeded
                  : WhatsAppSavedKind.restartRequested)
            : WhatsAppSavedKind.noRestart,
        restartError: result.restartError?.text,
      );

  @override
  String toString() => 'WhatsAppSavedOutcome($kind)';
}

/// Whether WhatsApp is already on for the repository's profile, read before
/// the pairing screen opens, so a later Check can tell a save from an earlier
/// setup. A read that fails or gets no answer for [timeout] counts as "already
/// on": Check then never reports a save it cannot prove.
Future<bool> whatsAppWasEnabled(
  HermesMessagingRepository repository, {
  Duration timeout = kWhatsAppAnswerTimeout,
}) async {
  try {
    final platforms = await repository.load().timeout(timeout);
    return platforms.any((p) => p.id == 'whatsapp' && p.enabled);
  } on Object {
    return true;
  }
}

/// Links a WhatsApp account to a profile by QR code: the form, the code, the
/// linked account and Finish. A thin screen over [WhatsAppPairingController]
/// and [WhatsAppPairingView]; everything it decides is the controller's.
///
/// The code is hidden when App Lock locks, when the lifecycle leaves
/// `resumed` (on a computer that is the window losing focus) and shows again
/// by itself on a tablet or computer, after a tap on a handset. Leaving
/// asks the server to drop an unfinished setup, once; the route cannot be
/// left while Finish is out.
///
/// Pops a [WhatsAppSavedOutcome] once the setup was saved.
class WhatsAppPairingScreen extends StatefulWidget {
  const WhatsAppPairingScreen({
    super.key,
    required this.repository,
    required this.profile,
    this.wasEnabled = true,
    this.telemetry,
    this.onUnsupported,
    this.now,
  });

  /// The repository of the Messaging list; the screen binds it to [profile].
  final HermesMessagingRepository repository;

  /// The profile the setup is saved for, explicit in every request.
  final String profile;

  /// WhatsApp was already on for [profile] before this screen opened (or that
  /// could not be read). Only a start from off lets Check report a save.
  final bool wasEnabled;

  final WhatsAppPairingTelemetry? telemetry;

  /// The server has no such route: the caller takes its entry point away.
  final VoidCallback? onUnsupported;

  /// The clock the countdown reads; the system's by default. A test sets it.
  final DateTime Function()? now;

  @override
  State<WhatsAppPairingScreen> createState() => _WhatsAppPairingScreenState();
}

class _WhatsAppPairingScreenState extends State<WhatsAppPairingScreen>
    with WidgetsBindingObserver {
  final _numbers = TextEditingController();
  WhatsAppPairingController? _controller;
  AppLockController? _lock;
  Timer? _tick;
  var _told = false;

  WhatsAppPairingController get _c => _controller!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final size = MediaQuery.sizeOf(context);
    final platform = Theme.of(context).platform;
    final computer = const {
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }.contains(platform);
    final controller = _controller = WhatsAppPairingController(
      repository: widget.repository,
      profile: widget.profile,
      // A computer's window shows the code at once, however narrow.
      handset: !computer && size.shortestSide < kWhatsAppHandsetShortestSide,
      followsWindowFocus: computer,
      telemetry: widget.telemetry,
      now: widget.now,
    );
    controller.addListener(_changed);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) {
      controller.setInForeground(false);
      if (computer) controller.setWindowFocused(false);
    }
    try {
      final lock = _lock = context.read<AppLockController>()
        ..addListener(_lockChanged);
      if (lock.locked) controller.cover();
    } on ProviderNotFoundException {
      /* Standalone screens need no App Lock. */
    }
    controller.open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _lock?.removeListener(_lockChanged);
    _controller
      ?..removeListener(_changed)
      ..dispose();
    _numbers.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    final front = state == AppLifecycleState.resumed;
    controller.setInForeground(front);
    if (controller.followsWindowFocus) controller.setWindowFocused(front);
  }

  void _lockChanged() {
    final lock = _lock!;
    if (lock.locked) {
      _c.cover();
    } else {
      _c.uncover();
    }
  }

  void _changed() {
    if (!mounted) return;
    final controller = _c;
    if (controller.phase == WhatsAppPairingPhase.unsupported && !_told) {
      _told = true;
      widget.onUnsupported?.call();
    }
    switch (controller.applyStatus) {
      case WhatsAppApplyStatus.saved:
        final result = controller.applyResult;
        dismissRoute(
          context,
          result == null ? null : WhatsAppSavedOutcome.fromApply(result),
        );
        return;
      case WhatsAppApplyStatus.checkEnabled when !widget.wasEnabled:
        dismissRoute(context, const WhatsAppSavedOutcome.checked());
        return;
      default:
        break;
    }
    // The countdown reads the clock, so the page ticks while it is shown.
    final counting = controller.timeLeft != null;
    if (counting && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_c.timeLeft == null) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else if (!counting) {
      _tick?.cancel();
      _tick = null;
    }
    setState(() {});
  }

  Future<void> _finish() async {
    if (!_c.requestFinish()) return;
    final confirmed = await askFinishWhatsApp(context);
    if (!mounted) return;
    if (confirmed) {
      unawaited(_c.confirmFinish());
    } else {
      _c.cancelFinish();
    }
  }

  void _leave() => unawaited(Navigator.of(context).maybePop());

  WhatsAppViewPhase get _phase => switch (_c.phase) {
    WhatsAppPairingPhase.setup => WhatsAppViewPhase.setup,
    WhatsAppPairingPhase.starting => WhatsAppViewPhase.starting,
    WhatsAppPairingPhase.startLost => WhatsAppViewPhase.startLost,
    WhatsAppPairingPhase.working => WhatsAppViewPhase.working,
    WhatsAppPairingPhase.waiting => WhatsAppViewPhase.waiting,
    WhatsAppPairingPhase.connected => WhatsAppViewPhase.connected,
    WhatsAppPairingPhase.failed => WhatsAppViewPhase.failed,
    WhatsAppPairingPhase.expired => WhatsAppViewPhase.expired,
    WhatsAppPairingPhase.superseded => WhatsAppViewPhase.superseded,
    WhatsAppPairingPhase.gone => WhatsAppViewPhase.gone,
    WhatsAppPairingPhase.unsupported => WhatsAppViewPhase.unsupported,
    WhatsAppPairingPhase.profileDeleted => WhatsAppViewPhase.profileDeleted,
  };

  WhatsAppFinishStatus get _finishStatus => switch (_c.applyStatus) {
    WhatsAppApplyStatus.applying => WhatsAppFinishStatus.applying,
    WhatsAppApplyStatus.refused => WhatsAppFinishStatus.refused,
    WhatsAppApplyStatus.lostAnswer => WhatsAppFinishStatus.lostAnswer,
    WhatsAppApplyStatus.checking => WhatsAppFinishStatus.checking,
    // Enabled where it was already on says nothing about this save.
    WhatsAppApplyStatus.checkEnabled ||
    WhatsAppApplyStatus.checkFailed => WhatsAppFinishStatus.checkFailed,
    WhatsAppApplyStatus.checkNotEnabled => WhatsAppFinishStatus.notSavedYet,
    _ => WhatsAppFinishStatus.idle,
  };

  QrCodeVisibility get _visibility => switch (_c.codeVisibility) {
    WhatsAppCodeVisibility.shown => QrCodeVisibility.shown,
    WhatsAppCodeVisibility.needsTap => QrCodeVisibility.needsTap,
    WhatsAppCodeVisibility.hidden => QrCodeVisibility.hidden,
  };

  WhatsAppStartProblem? get _startProblem {
    final failure = _c.startFailure;
    if (failure == null) return null;
    return failure.kind == WhatsAppPairingFailureKind.unreachable
        ? WhatsAppStartProblem.offline
        : WhatsAppStartProblem.refused;
  }

  WhatsAppNumbersIssue? get _numbersIssue => switch (_c.numbersProblem) {
    null => null,
    WhatsAppNumbersProblem.notPhoneNumber ||
    WhatsAppNumbersProblem.address => WhatsAppNumbersIssue.notPhoneNumber,
    WhatsAppNumbersProblem.everyone => WhatsAppNumbersIssue.everyone,
  };

  /// The server's own text for whichever banner or end is up.
  String? get _serverText =>
      _c.applyFailure?.serverText?.text ??
      _c.startFailure?.serverText?.text ??
      _c.serverText?.text;

  @override
  Widget build(BuildContext context) {
    final controller = _c;
    final account = controller.account;
    return PopScope(
      canPop: controller.canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(controller.leave());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const AdaptiveBackButton(previousTitle: 'Messaging'),
          leadingWidth: adaptiveBackLeadingWidth(context),
          title: Text(context.l10n.messagingWhatsappTitle),
        ),
        body: ContentColumn(
          child: WhatsAppPairingView(
            phase: _phase,
            handset: controller.handset,
            mode: controller.mode,
            numbers: _numbers,
            numbersIssue: _numbersIssue,
            startProblem: _startProblem,
            serverText: _serverText,
            workStage: controller.workStage,
            codeVisibility: _visibility,
            qrPayload: controller.qr?.value,
            timeLeft: controller.timeLeft,
            paused: controller.pausedLine,
            offline: controller.pollFailing,
            alreadyLinked: controller.alreadyLinked,
            accountName: account?.name,
            accountPhone: account?.phone,
            profile: widget.profile,
            selfChatBlankNumbers:
                controller.mode == WhatsAppMode.selfChat &&
                parseWhatsAppAllowedUsers(controller.allowedUsers).normalized ==
                    null,
            finish: _finishStatus,
            refreshing: controller.refreshing,
            refreshFailed: controller.refreshFailed,
            goneDuringApply: controller.goneDuringApply,
            onModeChanged: controller.setMode,
            onNumbersChanged: controller.setAllowedUsers,
            onStart: controller.canStart ? () => unawaited(_start()) : null,
            onStartAgain: controller.startAgain,
            onCancel: _leave,
            onShowQr: controller.revealQr,
            onFinish: controller.canFinish ? () => unawaited(_finish()) : null,
            onCheck: controller.canCheck
                ? () => unawaited(controller.check())
                : null,
            onBack: _leave,
          ),
        ),
      ),
    );
  }

  Future<void> _start() {
    _c.setAllowedUsers(_numbers.text);
    return _c.start();
  }
}
