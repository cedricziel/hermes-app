import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../voice/calls/active_call.dart';
import '../../voice/on_device_speech.dart';

/// On-device speech and the running call, which the lock cover and the shell
/// strip read.
List<SingleChildWidget> voiceProviders() => [
  ChangeNotifierProvider<ActiveCallRegistry>(
    create: (_) => ActiveCallRegistry(),
  ),
  // One app-wide listener: the recognizer's event channel has a single
  // native sink.
  Provider<OnDeviceSpeech>(
    create: (_) => OnDeviceSpeech(),
    dispose: (_, speech) => speech.dispose(),
  ),
];
