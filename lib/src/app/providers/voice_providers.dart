import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../voice/on_device_speech.dart';

/// On-device speech.
List<SingleChildWidget> voiceProviders() => [
  // One app-wide listener: the recognizer's event channel has a single
  // native sink.
  Provider<OnDeviceSpeech>(
    create: (_) => OnDeviceSpeech(),
    dispose: (_, speech) => speech.dispose(),
  ),
];
