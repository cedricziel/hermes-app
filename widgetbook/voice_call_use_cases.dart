import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';
import 'package:hermes_app/src/voice/calls/call_readiness.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_setup_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode voiceCallNode() => WidgetbookComponent(
  name: 'VoiceCallView',
  useCases: [
    for (final entry in <String, CallReadiness>{
      'Checking prerequisites': CallReadiness.checking,
      'Ready to call': const CallReadiness([
        CallCheck(
          CallCheckId.microphone,
          CallCheckStatus.ready,
          'Microphone access is allowed.',
        ),
        CallCheck(
          CallCheckId.input,
          CallCheckStatus.ready,
          'Apple on-device recognition is ready.',
        ),
        CallCheck(
          CallCheckId.output,
          CallCheckStatus.ready,
          'Hermes speech output is configured.',
        ),
        CallCheck(
          CallCheckId.connection,
          CallCheckStatus.ready,
          'The voice service is reachable.',
        ),
      ], useDeviceSpeech: true),
      'Server setup needed': const CallReadiness([
        CallCheck(
          CallCheckId.microphone,
          CallCheckStatus.ready,
          'Microphone access is allowed.',
        ),
        CallCheck(
          CallCheckId.input,
          CallCheckStatus.ready,
          'Apple on-device recognition is ready.',
        ),
        CallCheck(
          CallCheckId.output,
          CallCheckStatus.needsSetup,
          'Configure a speech provider on Hermes.',
          action: CallSetupAction.hermes,
        ),
        CallCheck(
          CallCheckId.connection,
          CallCheckStatus.unavailable,
          'The voice service could not be reached. Check your connection or update Hermes.',
          action: CallSetupAction.hermes,
        ),
      ], useDeviceSpeech: true),
      'Device setup needed': const CallReadiness([
        CallCheck(
          CallCheckId.microphone,
          CallCheckStatus.needsSetup,
          'Allow Hermes to use your microphone.',
          action: CallSetupAction.microphone,
        ),
        CallCheck(
          CallCheckId.input,
          CallCheckStatus.needsSetup,
          'Install your speech language in Dictation settings.',
          action: CallSetupAction.dictation,
        ),
        CallCheck(
          CallCheckId.output,
          CallCheckStatus.ready,
          'Hermes speech output is configured.',
        ),
        CallCheck(
          CallCheckId.connection,
          CallCheckStatus.ready,
          'The voice service is reachable.',
        ),
      ], useDeviceSpeech: true),
    }.entries)
      WidgetbookUseCase(
        name: entry.key,
        builder: (_) => frame(
          VoiceCallSetupView(
            readiness: entry.value,
            onClose: () {},
            onRetry: () {},
            onStart: () {},
            onMicrophone: () {},
            onDictation: () {},
            onAskHermes: () {},
          ),
        ),
      ),
    for (final sending in [false, true])
      WidgetbookUseCase(
        name: sending ? 'Sending setup request' : 'Setup request failed',
        builder: (_) => frame(
          VoiceCallSetupView(
            readiness: const CallReadiness([
              CallCheck(
                CallCheckId.output,
                CallCheckStatus.needsSetup,
                'Configure a speech provider on Hermes.',
                action: CallSetupAction.hermes,
              ),
            ]),
            busy: sending,
            error: sending
                ? null
                : 'The setup request could not be sent. Try again.',
            onClose: () {},
            onRetry: () {},
            onStart: () {},
            onAskHermes: () {},
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'Microphone denied',
      builder: (_) => frame(
        VoiceCallSetupView(
          readiness: const CallReadiness([
            CallCheck(
              CallCheckId.microphone,
              CallCheckStatus.needsSetup,
              'Allow Hermes to use your microphone.',
              action: CallSetupAction.microphone,
            ),
          ]),
          microphoneDenied: true,
          onClose: () {},
          onRetry: () {},
          onStart: () {},
          onMicrophone: () {},
        ),
      ),
    ),
    for (final phase in CallPhase.values)
      WidgetbookUseCase(
        name: phase.name,
        builder: (_) => frame(
          VoiceCallView(
            phase: phase,
            elapsed: const Duration(minutes: 2, seconds: 14),
            muted: false,
            speaker: false,
            route: 'iPhone',
            caption: phase == CallPhase.thinking || phase == CallPhase.speaking
                ? 'What does my afternoon look like?'
                : '',
            error: phase == CallPhase.failed
                ? 'The connection was interrupted. Your messages are saved in the chat.'
                : null,
            onMute: () {},
            onSpeaker: () {},
            onEnd: () {},
            onShowChat: () {},
            onAskHermes: phase == CallPhase.failed ? () {} : null,
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'Muted on car audio',
      builder: (_) => frame(
        VoiceCallView(
          phase: CallPhase.listening,
          elapsed: const Duration(minutes: 12),
          muted: true,
          speaker: false,
          route: 'Car audio',
          onMute: () {},
          onSpeaker: () {},
          onEnd: () {},
          onShowChat: () {},
        ),
      ),
    ),
  ],
);
