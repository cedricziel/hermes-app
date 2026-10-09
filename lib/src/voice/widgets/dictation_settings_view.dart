import 'package:flutter/material.dart';

import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_list.dart';
import '../dictation_settings.dart';
import '../on_device_speech.dart';

/// The Dictation setting: who turns speech into text, and the state of the
/// device's speech model for the user's language.
class DictationSettingsView extends StatelessWidget {
  const DictationSettingsView({
    super.key,
    required this.engine,
    required this.model,
    required this.onEngine,
    required this.onRetryDownload,
    this.progress,
    this.downloadFailed = false,
  });

  final DictationEngine engine;
  final OnDeviceModel model;

  /// How far the model download is, from 0 to 1; null while unknown.
  final double? progress;
  final bool downloadFailed;
  final ValueChanged<DictationEngine> onEngine;
  final VoidCallback onRetryDownload;

  @override
  Widget build(BuildContext context) {
    final supported = model != OnDeviceModel.unsupported;
    final downloading = model == OnDeviceModel.downloading && !downloadFailed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<DictationEngine>(
          groupValue: engine,
          onChanged: (engine) {
            if (engine != null) onEngine(engine);
          },
          child: GroupedSection(
            dividerIndent: GroupedChoiceRow.dividerIndent(context),
            footer:
                'Hermes uses the chat profile’s speech-to-text on your server. '
                'On this device turns speech into text here, without a '
                'connection, and it never leaves the device: Hermes only sees '
                'the message you send.',
            children: [
              const GroupedChoiceRow(
                key: Key('dictation-hermes'),
                value: DictationEngine.hermes,
                title: 'Hermes',
                subtitle: 'On your server',
              ),
              GroupedChoiceRow(
                key: const Key('dictation-device'),
                value: DictationEngine.device,
                title: 'On this device',
                enabled: supported,
                subtitle: _deviceSubtitle(downloading),
                warning: downloadFailed
                    ? 'The speech model didn’t download.'
                    : null,
              ),
            ],
          ),
        ),
        if (engine == DictationEngine.device && downloadFailed)
          GroupedSection(
            children: [
              GroupedRow(
                key: const Key('dictation-retry-download'),
                title: 'Try Again',
                chevron: false,
                onTap: onRetryDownload,
              ),
            ],
          ),
      ],
    );
  }

  String _deviceSubtitle(bool downloading) => switch (model) {
    OnDeviceModel.unsupported => 'Not available for your language',
    OnDeviceModel.installed => 'Ready',
    _ when downloading => switch (progress) {
      final fraction? => 'Downloading… ${(fraction * 100).round()}%',
      null => 'Downloading…',
    },
    _ => 'Downloads a speech model once',
  };
}
