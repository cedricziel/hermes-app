import 'package:record/record.dart';

/// The existing recording plugin can query access without showing a prompt.
/// Dispose it before CallKit starts, so it cannot alter an active call session.
Future<bool> callMicrophonePermission({bool request = false}) async {
  final recorder = AudioRecorder();
  try {
    return await recorder.hasPermission(request: request);
  } finally {
    await recorder.dispose();
  }
}
