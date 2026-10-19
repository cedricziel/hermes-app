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
        thread != null &&
        !thread.isReplying &&
        !thread.isCanonicalBotChat &&
        _chat.queuedIn(thread).isEmpty;
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
    final breadcrumbs = _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none;
    breadcrumbs('voice_call.opened');
    try {
      final auth = _maybeRead<AuthController>()!;
      final api = auth.api!;
      final baseUrl = auth.baseUrl!;
      final repository = _chat.repository!;
      final profile = _chat.profile;
      final thread = _chat.selectedThread;
      final settings = _maybeRead<DictationSettings>();
      final onDevice = _maybeRead<OnDeviceSpeech>();
      var locale = OnDeviceSpeech.deviceLocale();
      bool ownerValid() =>
          mounted &&
          _chat.active &&
          _sessionActivity?.value != false &&
          identical(_maybeRead<AuthController>(), auth) &&
          identical(auth.api, api) &&
          auth.baseUrl == baseUrl &&
          _chat.profile == profile &&
          identical(_chat.selectedThread, thread) &&
          _recipientSendAllowed &&
          _chat.modelSendAllowed;
      bool current() => _callRouteOpen && ownerValid();
      final connect = hermesMixedSocketConnect(
        baseUrl: baseUrl,
        authRequired: auth.status?.authRequired ?? true,
        api: api,
        path: '/api/audio/speak-stream',
      );
      final checker = CallReadinessChecker(
        isCurrent: current,
        beforeCheck: () async {
          await _voiceRecording?.cancel();
          await _dictation?.controller.cancel();
        },
        microphone: () => callMicrophonePermission(),
        input: () async {
          if (settings?.loaded == false) await settings!.load();
          locale = OnDeviceSpeech.deviceLocale();
          final chosen = settings?.engine ?? DictationEngine.device;
          final model = chosen == DictationEngine.hermes || onDevice == null
              ? OnDeviceModel.unsupported
              : await onDevice.status(locale);
          final device =
              effectiveDictationEngine(chosen, model) == DictationEngine.device;
          return CallInput(
            useDevice: device,
            installed: model == OnDeviceModel.installed,
          );
        },
        configuration: () => repository.voiceConfiguration(profile: profile),
        connection: () => probeCallSpeech(connect, profile, isCurrent: current),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (routeContext) => VoiceCallScreen(
            checker: checker,
            isCurrent: current,
            ongoing: _voiceCall?.ended == false ? _voiceCall : null,
            requestMicrophone: () => callMicrophonePermission(request: true),
            openMicrophoneSettings: () async {
              if (!await launchUrl(Uri.parse('app-settings:'))) {
                throw StateError('Settings could not be opened');
              }
            },
            openDictation: () => showDictationDialog(routeContext),
            askHermes: (report) async {
              if (!current() || !report.canAskHermes) return false;
              // Normal chat submission preserves the composer's draft/files.
              final accepted = await _chat.submit(report.setupPrompt, const []);
              breadcrumbs('voice_call.setup_requested', {'accepted': accepted});
              return accepted;
            },
            startCall: (readiness) {
              if (!current() ||
                  thread == null ||
                  thread.isReplying ||
                  _chat.queuedIn(thread).isNotEmpty) {
                throw StateError('The chat changed before the call started');
              }
              final previous = _voiceCall;
              previous?.removeListener(_callChanged);
              previous?.dispose();
              _sessionActivity?.removeListener(_callOwnerChanged);
              late final VoiceCall created;
              final agent = ChatCallAgent(
                _chat,
                onContextLost: () => unawaited(created.end()),
              );
              created = VoiceCall(
                bridge: AppleCallBridge(),
                agent: agent,
                profile: profile,
                connect: connect,
                speechFallback: (text, speechProfile, cancellation) async {
                  if (!ownerValid() || cancellation.isCancelled) {
                    throw StateError('The call changed');
                  }
                  breadcrumbs('voice_call.speech_fallback');
                  final audio = await repository.synthesize(
                    text,
                    profile: speechProfile,
                    cancellation: cancellation,
                  );
                  if (!ownerValid()) throw StateError('The call changed');
                  return decodeCallAudio(audio, cancellation);
                },
                prepare: () async {
                  if (!ownerValid() || !agent.valid) {
                    throw const CallPreparationException(
                      'This chat changed. Start the call again.',
                    );
                  }
                },
                transcribe: (wav) => readiness.useDeviceSpeech
                    ? onDevice!.transcribeFile(wav, locale: locale)
                    : repository.transcribe(
                        wav,
                        mimeType: 'audio/wav',
                        profile: profile,
                        timeout: const Duration(seconds: 60),
                      ),
              );
              _voiceCall = created;
              breadcrumbs('voice_call.ready', {
                'device_speech': readiness.useDeviceSpeech,
              });
              _callHasEnded = false;
              created.addListener(_callChanged);
              _sessionActivity?.addListener(_callOwnerChanged);
              _rebuild(() {});
              return created;
            },
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
