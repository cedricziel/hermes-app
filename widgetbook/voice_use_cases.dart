import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/voice/on_device_speech.dart';
import 'package:hermes_app/src/voice/widgets/dictation_settings_view.dart';
import 'package:hermes_app/src/voice/widgets/dictation_notice.dart';
import 'package:hermes_app/src/voice/widgets/voice_waveform.dart';
import 'package:hermes_app/src/voice/widgets/voice_message_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookNode voiceNode() => WidgetbookFolder(
  name: 'Voice',
  children: [
    WidgetbookComponent(
      name: 'VoiceMessageView',
      useCases: [
        for (final state in [
          'Ready',
          'Loading',
          'Playing',
          'Paused',
          'Failed',
          'Missing',
          'Transcript',
          'Transcript expanded',
        ])
          WidgetbookUseCase(
            name: state,
            builder: (_) => frame(
              VoiceMessageView(
                name: 'Morning briefing.mp3',
                transcript: state.startsWith('Transcript')
                    ? 'Your morning briefing: the nightly backup completed successfully. You have two meetings today, starting at ten.'
                    : null,
                initiallyExpanded: state == 'Transcript expanded',
                loading: state == 'Loading',
                playing: state == 'Playing',
                position: state == 'Playing' || state == 'Paused'
                    ? const Duration(seconds: 12)
                    : Duration.zero,
                duration: state == 'Playing' || state == 'Paused'
                    ? const Duration(seconds: 48)
                    : Duration.zero,
                error: switch (state) {
                  'Failed' => 'Could not play this audio. Try again.',
                  'Missing' => 'This file is no longer available.',
                  _ => null,
                },
                onToggle: state == 'Missing' ? null : () {},
                onSeek: (_) {},
                onSave: () {},
              ),
            ),
          ),
      ],
    ),
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
          'On this device',
          const VoiceWaveform(
            levels: dictationLevels,
            elapsed: Duration(seconds: 9),
            onDevice: true,
          ),
        ),
        _waveform(
          'Through Hermes',
          const VoiceWaveform(
            levels: dictationLevels,
            elapsed: Duration(seconds: 9),
            onDevice: false,
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
      ],
    ),
    WidgetbookComponent(
      name: 'DictationNotice',
      useCases: [
        _notice('Failed, with Retry', DictationPhase.failed, retry: true),
        _notice('No speech', DictationPhase.noSpeech),
        _notice('Microphone access off', DictationPhase.denied),
        _notice('Speech model missing', DictationPhase.modelMissing),
      ],
    ),
    WidgetbookComponent(
      name: 'DictationSettingsView',
      useCases: [
        _settings('Hermes', DictationEngine.hermes, OnDeviceModel.installed),
        _settings(
          'On this device, ready',
          DictationEngine.device,
          OnDeviceModel.installed,
        ),
        _settings(
          'Model not downloaded',
          DictationEngine.hermes,
          OnDeviceModel.missing,
        ),
        _settings(
          'Downloading',
          DictationEngine.device,
          OnDeviceModel.downloading,
          progress: 0.4,
        ),
        _settings(
          'Download failed',
          DictationEngine.device,
          OnDeviceModel.missing,
          downloadFailed: true,
        ),
        _settings(
          'Not supported',
          DictationEngine.hermes,
          OnDeviceModel.unsupported,
        ),
      ],
    ),
  ],
);

WidgetbookUseCase _settings(
  String name,
  DictationEngine engine,
  OnDeviceModel model, {
  double? progress,
  bool downloadFailed = false,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => frame(
    DictationSettingsView(
      engine: engine,
      model: model,
      progress: progress,
      downloadFailed: downloadFailed,
      onEngine: (_) {},
      onRetryDownload: () {},
    ),
  ),
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
