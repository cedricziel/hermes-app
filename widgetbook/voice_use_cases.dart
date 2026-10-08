import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/widgets/dictation_notice.dart';
import 'package:hermes_app/src/voice/widgets/voice_waveform.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookNode voiceNode() => WidgetbookFolder(
  name: 'Voice',
  children: [
    WidgetbookComponent(
      name: 'VoiceWaveform',
      useCases: [
        _waveform(
          'Recording',
          const VoiceWaveform(
            levels: dictationLevels,
            elapsed: Duration(seconds: 7),
          ),
        ),
        _waveform(
          'Recording, quiet',
          const VoiceWaveform(
            levels: [0.02, 0.03, 0.02, 0.04],
            elapsed: Duration(seconds: 2),
          ),
        ),
        _waveform(
          'Live transcript',
          const VoiceWaveform(
            levels: dictationLevels,
            elapsed: Duration(seconds: 12),
            liveTranscript: dictationLiveTranscript,
          ),
        ),
        _waveform(
          'Transcribing',
          const VoiceWaveform(
            levels: dictationLevels,
            elapsed: Duration(seconds: 15),
            settling: true,
          ),
        ),
        _waveform(
          'Near the time limit',
          const VoiceWaveform(
            levels: dictationLevels,
            elapsed: Duration(minutes: 4, seconds: 58),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'DictationNotice',
      useCases: [
        _notice('Failed, with Retry', DictationPhase.failed, retry: true),
        _notice('No speech', DictationPhase.noSpeech),
        _notice('Microphone access off', DictationPhase.denied),
      ],
    ),
  ],
);

WidgetbookUseCase _waveform(String name, VoiceWaveform waveform) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => frame(waveform, maxWidth: 760),
    );

WidgetbookUseCase _notice(
  String name,
  DictationPhase phase, {
  bool retry = false,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => frame(
    DictationNotice(
      phase: phase,
      onDismiss: () {},
      onRetry: retry ? () {} : null,
    ),
    maxWidth: 760,
  ),
);
