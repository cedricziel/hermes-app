import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/on_device_speech.dart';

/// Answers the on-device recognizer's platform channels, so tests drive the
/// real [OnDeviceSpeech] the way the iOS and macOS plugin would.
class FakeSpeechChannel {
  FakeSpeechChannel() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _messenger.setMockMethodCallHandler(OnDeviceSpeech.methods, _answer);
    _messenger.setMockStreamHandler(
      OnDeviceSpeech.events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          _events = sink;
        },
      ),
    );
  }

  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// What `status` answers: `unsupported`, `missing`, `downloading` or
  /// `installed`; `start` fails with `modelMissing` unless `installed`.
  String status = 'installed';

  /// What `finish` answers; a code here makes it fail with that code.
  String transcript = '';
  String? finishError;

  Completer<void>? _install;
  final calls = <MethodCall>[];
  final audio = <int>[];
  MockStreamHandlerEventSink? _events;
  var _session = 0;

  Iterable<String> get methods => calls.map((c) => c.method);

  /// The recognizer's latest text for the open session.
  void hears(String text) =>
      _events?.success({'id': _session, 'type': 'partial', 'text': text});

  /// How far the model download is. In a widget test, call it inside
  /// `tester.runAsync`: the event is delivered outside the fake clock.
  Future<void> progress(double fraction) async {
    // Lets a listen that is still being set up arrive first.
    await Future<void>.delayed(Duration.zero);
    _events?.success({'type': 'progress', 'fraction': fraction});
    await Future<void>.delayed(Duration.zero);
  }

  /// Ends the `install` in progress.
  void completeInstall() {
    status = 'installed';
    _install?.complete();
    _install = null;
  }

  void failInstall(String code) {
    _install?.completeError(PlatformException(code: code));
    _install = null;
  }

  /// The recognizer fails mid-recording.
  void fails(String code) =>
      _events?.success({'id': _session, 'type': 'error', 'code': code});

  void dispose() {
    _messenger.setMockMethodCallHandler(OnDeviceSpeech.methods, null);
    _messenger.setMockStreamHandler(OnDeviceSpeech.events, null);
  }

  Future<Object?> _answer(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'status':
        return status;
      case 'install':
        status = 'downloading';
        await (_install = Completer()).future;
        return null;
      case 'start':
        if (status != 'installed') {
          throw PlatformException(code: 'modelMissing');
        }
        return ++_session;
      case 'append':
        audio.addAll((call.arguments as Map)['pcm'] as Uint8List);
        return null;
      case 'finish':
        if (finishError case final code?) throw PlatformException(code: code);
        return transcript;
    }
    return null;
  }
}
