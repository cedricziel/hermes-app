import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode voiceCallNode() => WidgetbookComponent(
  name: 'VoiceCallView',
  useCases: [
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
