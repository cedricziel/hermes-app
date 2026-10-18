part of 'chat_screen.dart';

extension _ChatScreenCalls on _ChatScreenState {
  bool get _canCall {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    if (_voiceCall case final call? when !call.ended) return true;
    final thread = _chat.selectedThread;
    return _chat.active &&
        _chat.repository != null &&
        _maybeRead<AuthController>()?.api != null &&
        _recipientSendAllowed &&
        _chat.modelSendAllowed &&
        !_chat.loadingThreads &&
        (thread != null &&
            (!thread.isReplying &&
                !thread.isCanonicalBotChat &&
                _chat.queuedIn(thread).isEmpty));
  }

  Widget? get _callButton => !_canCall
      ? null
      : NamedIconButton(
          key: const Key('header-voice-call'),
          label: _voiceCall?.ended == false
              ? 'Return to call'
              : 'Start voice call',
          icon: AppIcons.call,
          onPressed: _openVoiceCall,
        );

  Future<void> _openVoiceCall() async {
    if (_callRouteOpen || !_canCall) return;
    _callRouteOpen = true;
    try {
      var call = _voiceCall;
      if (call == null || call.ended) {
        call?.removeListener(_callChanged);
        call?.dispose();
        _sessionActivity?.removeListener(_callOwnerChanged);
        final auth = _maybeRead<AuthController>()!;
        final repository = _chat.repository!;
        final api = auth.api!;
        final profile = _chat.profile;
        final settings = _maybeRead<DictationSettings>();
        final onDevice = _maybeRead<OnDeviceSpeech>();
        final locale = OnDeviceSpeech.deviceLocale();
        var device = false;
        late final VoiceCall created;
        final agent = ChatCallAgent(
          _chat,
          onContextLost: () => unawaited(created.end()),
        );
        created = VoiceCall(
          bridge: AppleCallBridge(),
          agent: agent,
          profile: profile,
          connect: hermesMixedSocketConnect(
            baseUrl: auth.baseUrl!,
            authRequired: auth.status?.authRequired ?? true,
            api: api,
            path: '/api/audio/speak-stream',
          ),
          prepare: () async {
            await _dictation?.controller.cancel();
            if (settings?.loaded == false) await settings!.load();
            final chosen = settings?.engine ?? DictationEngine.device;
            final model = onDevice == null
                ? OnDeviceModel.unsupported
                : await onDevice.status(locale);
            device =
                effectiveDictationEngine(chosen, model) ==
                DictationEngine.device;
            if (device && model != OnDeviceModel.installed) {
              throw const CallPreparationException(
                'Install your speech language in Dictation settings before calling.',
              );
            }
            final support = await repository.voiceSupport(profile: profile);
            if (!support.textToSpeech || (!device && !support.speechToText)) {
              throw const CallPreparationException(
                'Configure speech providers on Hermes before calling.',
              );
            }
            if (!agent.valid) {
              throw StateError('The chat changed before the call started.');
            }
          },
          transcribe: (wav) => device
              ? onDevice!.transcribeFile(wav, locale: locale)
              : repository.transcribe(
                  wav,
                  mimeType: 'audio/wav',
                  profile: profile,
                  timeout: const Duration(seconds: 60),
                ),
        );
        call = _voiceCall = created;
        _callHasEnded = false;
        call.addListener(_callChanged);
        _sessionActivity?.addListener(_callOwnerChanged);
        unawaited(call.start());
        _rebuild(() {});
      }
      if (!mounted) return;
      final ongoing = call;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            body: ListenableBuilder(
              listenable: ongoing,
              builder: (context, _) => VoiceCallView(
                phase: ongoing.phase,
                elapsed: ongoing.elapsed,
                muted: ongoing.muted,
                speaker: ongoing.speaker,
                route: ongoing.route,
                caption: ongoing.caption,
                error: ongoing.error,
                onMute: () => unawaited(ongoing.setMuted(!ongoing.muted)),
                onSpeaker: () =>
                    unawaited(ongoing.setSpeaker(!ongoing.speaker)),
                onEnd: () => unawaited(ongoing.end()),
                onShowChat: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      );
    } finally {
      _callRouteOpen = false;
      if (mounted) _rebuild(() {});
    }
  }

  void _callChanged() {
    final ended = _voiceCall?.ended ?? true;
    if (ended != _callHasEnded) {
      _callHasEnded = ended;
      if (mounted) _rebuild(() {});
    }
  }

  void _callOwnerChanged() {
    if (_sessionActivity?.value == false) unawaited(_voiceCall?.end());
  }
}
