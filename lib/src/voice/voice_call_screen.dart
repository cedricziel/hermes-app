import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'calls/call_readiness.dart';
import 'calls/call_readiness_checker.dart';
import 'calls/voice_call.dart';
import 'widgets/voice_call_footer.dart';
import 'widgets/voice_call_notice.dart';
import 'widgets/voice_call_setup_view.dart';
import 'widgets/voice_call_view.dart';

/// One route from checking to an active call. Closing checks never starts a
/// call or sends a setup prompt; minimizing an active call keeps it running.
///
/// A call starts only when the user turned on "Send what I say automatically"
/// and pressed Start. The switch lives in this screen's state: off on every
/// open and after "Start a new call", never stored.
class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({
    super.key,
    required this.checker,
    required this.isCurrent,
    required this.startCall,
    required this.requestMicrophone,
    required this.openMicrophoneSettings,
    this.canOpenMicrophoneSettings = true,
    required this.openDictation,
    required this.askHermes,
    this.ongoing,
    this.onConsentGiven,
  });
  final CallReadinessChecker checker;
  final bool Function() isCurrent;
  final VoiceCall Function(CallReadiness, {required bool consented}) startCall;

  /// Runs when a call starts with the consent switch on.
  final VoidCallback? onConsentGiven;
  final Future<bool> Function() requestMicrophone;
  final Future<void> Function() openMicrophoneSettings, openDictation;

  /// Whether this system has a page [openMicrophoneSettings] can open. Without
  /// one a denied microphone keeps offering Allow instead of Open Settings.
  final bool canOpenMicrophoneSettings;
  final Future<bool> Function(CallReadiness) askHermes;
  final VoiceCall? ongoing;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with WidgetsBindingObserver {
  CallReadiness _readiness = CallReadiness.checking;
  VoiceCall? _call;
  bool _busy = false, _denied = false, _checking = false, _consent = false;
  int _generation = 0;
  String? _error;
  bool get _current =>
      mounted &&
      widget.isCurrent() &&
      ModalRoute.of(context)?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _call = widget.ongoing;
    if (_call == null) unawaited(_check());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _call == null &&
        !_busy &&
        !_readiness.isChecking &&
        _current) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_checking || _call != null) return;
    _checking = true;
    final generation = ++_generation;
    setState(() {
      _readiness = CallReadiness.checking;
      _error = null;
    });
    try {
      final report = await widget.checker.check(
        onUpdate: (value) {
          if (_current && generation == _generation) {
            setState(() => _readiness = value);
          }
        },
      );
      if (!mounted || generation != _generation) return;
      if (!widget.isCurrent()) {
        setState(() {
          _error =
              'This chat changed. Close this screen and start the call again.';
          _readiness = const CallReadiness([
            CallCheck(
              CallCheckId.connection,
              CallCheckStatus.unavailable,
              'Return to the chat to start again.',
            ),
          ]);
        });
        return;
      }
      if (!_current) return;
      setState(() => _readiness = report);
    } on Object {
      if (!_current || generation != _generation) return;
      setState(() {
        _error =
            'Could not check voice setup. Close this screen and try again.';
        _readiness = const CallReadiness([
          CallCheck(
            CallCheckId.connection,
            CallCheckStatus.unavailable,
            'Voice setup could not be checked. Try again.',
          ),
        ]);
      });
    } finally {
      _checking = false;
    }
  }

  void _start() {
    if (!_current || !_consent || !_readiness.ready || _call != null || _busy) {
      return;
    }
    try {
      final call = widget.startCall(_readiness, consented: _consent);
      widget.onConsentGiven?.call();
      setState(() => _call = call);
      unawaited(call.start());
    } on Object {
      // startCall throws a StateError when the chat changed, an ordinary case.
      setState(
        () => _error =
            'This chat changed. Close this screen and start the call again.',
      );
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (!_current || _busy || _readiness.isChecking) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object {
      if (_current) {
        setState(() => _error = 'That action could not finish. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back to the start screen with the switch off.
  void _startNew() {
    if (!_current) return;
    setState(() {
      _call = null;
      _consent = false;
      _error = null;
    });
    unawaited(_check());
  }

  Future<void> _useDictation() async {
    if (!_current || _busy) return;
    _generation++;
    try {
      await widget.openDictation();
    } on Object {
      // Closing is the answer either way.
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget? _notice(BuildContext context, VoiceCall call) {
    final l10n = context.l10n;
    return switch ((call.notice, call.endReason, call.ended)) {
      (CallNotice.microphoneMayBeOpen, _, _) => VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: l10n.voiceNoticeMicMayBeOpenTitle,
        detail: l10n.voiceNoticeMicMayBeOpenDetail,
      ),
      (CallNotice.routeChanged, _, _) => VoiceCallNotice(
        title: l10n.voiceNoticeRouteTitle,
      ),
      (CallNotice.routeChangedNeutral, _, _) => VoiceCallNotice(
        title: l10n.voiceNoticeRouteNeutralTitle,
      ),
      (CallNotice.idle, _, _) => VoiceCallNotice(
        title: l10n.voiceNoticeIdleTitle,
        detail: l10n.voiceNoticeIdleDetail,
      ),
      (CallNotice.left, _, _) => VoiceCallNotice(
        title: l10n.voiceNoticeLeftTitle,
        detail: l10n.voiceNoticeLeftDetail,
      ),
      (CallNotice.speechFailed, _, _) => VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: l10n.voiceNoticeSpeechFailedTitle,
        detail: l10n.voiceNoticeSpeechFailedDetail,
      ),
      (CallNotice.transcription, _, _) => VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: l10n.voiceNoticeTranscriptionTitle,
      ),
      (CallNotice.busy, _, _) => VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: l10n.voiceNoticeBusyTitle,
      ),
      (CallNotice.notSent, _, _) => VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: l10n.voiceNoticeNotSentTitle,
      ),
      (CallNotice.hermesQueued, _, _) => VoiceCallNotice(
        title: l10n.voiceNoticeHermesQueuedTitle,
      ),
      (CallNotice.hermesSteered, _, _) => VoiceCallNotice(
        title: l10n.voiceNoticeHermesSteeredTitle,
      ),
      (CallNotice.hermesRedirected, _, _) => VoiceCallNotice(
        title: l10n.voiceNoticeHermesRedirectedTitle,
      ),
      (_, 'interrupted' || 'focus_lost', true) => VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: l10n.voiceNoticeInterruptedTitle,
        detail: l10n.voiceNoticeInterruptedDetail,
      ),
      (_, final reason, true) when _endedByUser(reason) => VoiceCallNotice(
        title: l10n.voiceNoticeEndedTitle,
        detail: l10n.voiceNoticeEndedDetail,
      ),
      _ => null,
    };
  }

  /// End, a stop phrase or the platform's hang-up, with no failure.
  bool _endedByUser(String? reason) =>
      reason == 'app' ||
      reason == 'stop_phrase' ||
      reason == 'voice_stopped' ||
      reason == 'hang_up';

  Future<void> _ask(CallReadiness report) async {
    if (!_current || _busy || !report.canAskHermes) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final accepted = await widget.askHermes(report);
      if (!mounted || !_current) return;
      if (accepted) {
        _generation++;
        Navigator.of(context).pop();
      } else {
        setState(
          () => _error = 'The setup request could not be sent. Try again.',
        );
      }
    } on Object {
      if (_current) {
        setState(
          () => _error = 'The setup request could not be sent. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Speaker routing exists on iOS and Android only.
  bool _speakerControl(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.android;

  /// iOS keeps a call running in the background; elsewhere it ends when the
  /// app is left, and the screen says so.
  VoiceCallFooter _footer(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => VoiceCallFooter.none,
    TargetPlatform.android => VoiceCallFooter.androidLeave,
    _ => VoiceCallFooter.desktopHide,
  };

  /// What Speaking tells the user about interrupting: speaking over the reply
  /// where the platform cancels its echo, otherwise the orb; on desktop the
  /// microphone is also closed meanwhile.
  VoiceSpeakingHint _speakingHint(VoiceCall call, TargetPlatform platform) {
    if (call.bargeInActive) return VoiceSpeakingHint.tapOrTalk;
    return _speakerControl(platform)
        ? VoiceSpeakingHint.tapOnly
        : VoiceSpeakingHint.micPaused;
  }

  @override
  Widget build(BuildContext context) {
    final call = _call;
    final platform = Theme.of(context).platform;
    return Scaffold(
      body: call != null
          ? ListenableBuilder(
              listenable: call,
              builder: (_, _) => VoiceCallView(
                phase: call.phase,
                elapsed: call.elapsed,
                muted: call.mutedRequested,
                speaker: call.speaker,
                route: call.route,
                caption: call.caption,
                error: call.notice != null || call.interruptedEnd
                    ? _error
                    : _error ?? call.error,
                notice: _notice(context, call),
                endedByUser:
                    call.phase == CallPhase.ended &&
                    _endedByUser(call.endReason),
                stoppedWord:
                    call.ended && (call.notice != null || call.interruptedEnd),
                onStartNew: call.ended ? _startNew : null,
                helpBusy: _busy,
                onAskHermes: () => unawaited(
                  _ask(
                    CallReadiness([
                      CallCheck(
                        CallCheckId.connection,
                        CallCheckStatus.unavailable,
                        call.error ?? 'The call could not continue.',
                        action: CallSetupAction.hermes,
                      ),
                    ], useDeviceSpeech: _readiness.useDeviceSpeech),
                  ),
                ),
                capturePaused:
                    call.phase == CallPhase.attention && call.capturePaused,
                showSpeaker: _speakerControl(platform),
                footer: _footer(platform),
                speakingHint: _speakingHint(call, platform),
                onInterrupt: call.phase == CallPhase.speaking
                    ? () => unawaited(call.interruptReply())
                    : null,
                onMute: () => unawaited(call.setMuted(!call.mutedRequested)),
                onSpeaker: () => unawaited(call.setSpeaker(!call.speaker)),
                onEnd: () => unawaited(call.end()),
                onShowChat: () => Navigator.of(context).pop(),
              ),
            )
          : VoiceCallSetupView(
              readiness: _readiness,
              gptLiveNote: _readiness.gptLive,
              footer: _footer(platform),
              busy: _busy,
              microphoneDenied: _denied,
              error: _error,
              onClose: () {
                _generation++;
                Navigator.of(context).pop();
              },
              onStart: _start,
              consented: _consent,
              onConsentChanged: (value) => setState(() => _consent = value),
              onUseDictation: () => unawaited(_useDictation()),
              onRetry: () => unawaited(_check()),
              onMicrophone: () => unawaited(
                _act(() async {
                  if (_denied) {
                    await widget.openMicrophoneSettings();
                    return;
                  }
                  final granted = await widget.requestMicrophone();
                  if (!_current) return;
                  setState(
                    () =>
                        _denied = !granted && widget.canOpenMicrophoneSettings,
                  );
                  await _check();
                }),
              ),
              onDictation: () => unawaited(
                _act(() async {
                  await widget.openDictation();
                  if (_current) await _check();
                }),
              ),
              onAskHermes: () => unawaited(_ask(_readiness)),
            ),
    );
  }
}
