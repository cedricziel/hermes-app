part of 'chat_screen.dart';

extension _ChatScreenCalls on _ChatScreenState {
  bool get _canCall {
    if (kIsWeb) return false;
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

  /// The Mac toolbar's version of [_callButton].
  Widget? get _macCallButton => !_canCall
      ? null
      : MacToolbarButton(
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
    // Read before the first await: the finally below runs after the route
    // closed, when this screen may be gone. The mark is closed by this
    // screen only, never by one that replaced it.
    final registry = _maybeRead<ActiveCallRegistry>()?..screenOpened(this);
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
      final telemetry = HermesRepositories.maybeOf(context)?.telemetry;
      final models = HermesRepositories.maybeOf(context)?.models;
      final events = telemetry?.events ?? noopAppEventLogger;
      // A tracer per socket: each turn and the readiness probe open their own,
      // and a tracer links its messages to the last upgrade it traced.
      Future<StreamChannel<Object?>> connect([
        Map<String, String> query = const {},
      ]) => hermesMixedSocketConnect(
        baseUrl: baseUrl,
        authRequired: auth.status?.authRequired ?? true,
        api: api,
        path: '/api/audio/speak-stream',
        telemetry: telemetry?.gateway(),
      )(query);
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
        voiceModel: () async => models == null
            ? VoiceModelRoute.unknown
            : models.loadVoiceRoute(profile: profile),
        gptLive: () => repository.voiceLiveIsGptLive(profile: profile),
        events: events,
      );
      final platform = Theme.of(context).platform;
      await showVoiceCall(
        context,
        builder: (routeContext) => VoiceCallScreen(
          checker: checker,
          isCurrent: current,
          ongoing: _voiceCall?.ended == false ? _voiceCall : null,
          requestMicrophone: () => callMicrophonePermission(request: true),
          canOpenMicrophoneSettings: canOpenMicrophoneSettings(platform),
          openMicrophoneSettings: () => openMicrophoneSettings(platform),
          openDictation: () => showDictationDialog(routeContext),
          askHermes: (report) async {
            if (!current() || !report.canAskHermes) return false;
            // Normal chat submission preserves the composer's draft/files.
            final accepted = await _chat.submit(report.setupPrompt, const []);
            breadcrumbs('voice_call.setup_requested', {'accepted': accepted});
            return accepted;
          },
          onConsentGiven: () => breadcrumbs('voice_call.consent'),
          startCall: (readiness, {required consented}) {
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
            final bridge = createCallBridge();
            final lease = CallTtsLease(repository, profile: profile);
            created = VoiceCall(
              holdLease: lease.hold,
              releaseLease: lease.release,
              bridge: bridge,
              tones: BridgeCallTones(bridge),
              haptics: SystemCallHaptics(),
              agent: agent,
              consented: consented,
              loadConfig: () => repository.voiceCallConfig(profile: profile),
              profile: profile,
              connect: connect,
              events: events,
              deviceSpeech: readiness.useDeviceSpeech,
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
            registry?.attach(created);
            _callRegistry = registry;
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
      );
    } finally {
      registry?.screenClosed(this);
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
