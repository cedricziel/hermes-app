import 'dart:async';

import 'package:flutter/material.dart';

import 'calls/call_readiness.dart';
import 'calls/call_readiness_checker.dart';
import 'calls/voice_call.dart';
import 'widgets/voice_call_setup_view.dart';
import 'widgets/voice_call_view.dart';

/// One route from checking to an active call. Closing checks never starts a
/// call or sends a setup prompt; minimizing an active call keeps it running.
class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({
    super.key,
    required this.checker,
    required this.isCurrent,
    required this.startCall,
    required this.requestMicrophone,
    required this.openMicrophoneSettings,
    required this.openDictation,
    required this.askHermes,
    this.ongoing,
  });
  final CallReadinessChecker checker;
  final bool Function() isCurrent;
  final VoiceCall Function(CallReadiness) startCall;
  final Future<bool> Function() requestMicrophone;
  final Future<void> Function() openMicrophoneSettings, openDictation;
  final Future<bool> Function(CallReadiness) askHermes;
  final VoiceCall? ongoing;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with WidgetsBindingObserver {
  CallReadiness _readiness = CallReadiness.checking;
  VoiceCall? _call;
  bool _busy = false, _denied = false, _checking = false;
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
      if (report.ready) _start();
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
    if (!_current || !_readiness.ready || _call != null || _busy) return;
    try {
      final call = widget.startCall(_readiness);
      setState(() => _call = call);
      unawaited(call.start());
    } on Object {
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
      if (_current && _readiness.ready && _call == null) _start();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final call = _call;
    return Scaffold(
      body: call != null
          ? ListenableBuilder(
              listenable: call,
              builder: (_, _) => VoiceCallView(
                phase: call.phase,
                elapsed: call.elapsed,
                muted: call.muted,
                speaker: call.speaker,
                route: call.route,
                caption: call.caption,
                error: _error ?? call.error,
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
                onMute: () => unawaited(call.setMuted(!call.muted)),
                onSpeaker: () => unawaited(call.setSpeaker(!call.speaker)),
                onEnd: () => unawaited(call.end()),
                onShowChat: () => Navigator.of(context).pop(),
              ),
            )
          : VoiceCallSetupView(
              readiness: _readiness,
              busy: _busy,
              microphoneDenied: _denied,
              error: _error,
              onClose: () {
                _generation++;
                Navigator.of(context).pop();
              },
              onStart: _start,
              onRetry: () => unawaited(_check()),
              onMicrophone: () => unawaited(
                _act(() async {
                  if (_denied) {
                    await widget.openMicrophoneSettings();
                    return;
                  }
                  final granted = await widget.requestMicrophone();
                  if (!_current) return;
                  setState(() => _denied = !granted);
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
