import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/voice/voice_audio_focus.dart';
import 'package:hermes_app/src/voice/voice_message_recording.dart';
import 'package:hermes_app/src/voice/voice_recording_view.dart';

import '../support/fake_voice_recorder.dart';

class _PendingPermission extends FakeVoiceRecorder {
  final gate = Completer<bool>();
  @override
  Future<bool> requestPermission() => gate.future;
}

class _PendingStart extends FakeVoiceRecorder {
  final gate = Completer<void>();
  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    await gate.future;
    return super.start(sampleRate: sampleRate);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FakeVoiceRecorder recorder;
  late VoiceMessageRecording recording;
  late List<SharedFile> files;
  late List<String> errors;
  late VoiceAudioFocus focus;

  Future<void> pumpAudio() => Future<void>.delayed(Duration.zero);
  VoiceMessageRecording create({
    ValueNotifier<bool>? activity,
    Future<Directory> Function()? cache,
  }) => recording = VoiceMessageRecording(
    recorder: recorder,
    directory: cache ?? () async => directory,
    focus: focus,
    activity: activity,
    onAttach: files.add,
    onError: errors.add,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes_record_test_');
    recorder = FakeVoiceRecorder();
    files = [];
    errors = [];
    focus = VoiceAudioFocus();
  });
  tearDown(() async {
    recording.dispose();
    await recording.whenClosed;
    focus.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'release attaches a playable WAV without uploading or changing text',
    () async {
      create();
      await recording.start();
      recorder.speak(List.filled(8000, 4000));
      await pumpAudio();
      expect(recording.phase, VoiceRecordingPhase.recording);
      expect(files, isEmpty);
      await recording.finish();
      expect(recorder.recording, isFalse);
      expect(files.single.mimeType, 'audio/wav');
      final wav = await File(files.single.path).readAsBytes();
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
      expect(wav.length, 44 + 16000);
      expect(errors, isEmpty);
    },
  );

  test(
    'release while permission is pending never starts a late microphone',
    () async {
      final pending = _PendingPermission();
      recorder = pending;
      create();
      final starting = recording.start();
      final finishing = recording.finish();
      pending.gate.complete(true);
      await starting;
      await finishing;
      expect(recorder.starts, 0);
      expect(files, isEmpty);
      expect(recording.busy, isFalse);
    },
  );

  test(
    'cancel while native start is pending stops the microphone after start',
    () async {
      final pending = _PendingStart();
      recorder = pending;
      create();
      final starting = recording.start();
      await pumpAudio();
      final cancelling = recording.cancel();
      pending.gate.complete();
      await starting;
      await cancelling;
      expect(recorder.starts, 1);
      expect(recorder.recording, isFalse);
      expect(files, isEmpty);
      expect(errors, isEmpty);
    },
  );

  test('denied permission preserves the draft and permits retry', () async {
    recorder.permission = false;
    create();
    await recording.start();
    expect(recording.busy, isFalse);
    expect(errors.single, contains('Microphone access'));
    recorder.permission = true;
    await recording.start();
    recorder.speak(List.filled(8000, 100));
    await pumpAudio();
    await recording.finish();
    expect(files, hasLength(1));
  });

  test('short recordings are discarded', () async {
    create();
    await recording.start();
    recorder.speak([1, 2, 3]);
    await pumpAudio();
    await recording.finish();
    expect(files, isEmpty);
    expect(errors.single, contains('too short'));
  });

  test('a cancelled pointer/session drops the recording', () async {
    final activity = ValueNotifier(true);
    create(activity: activity);
    await recording.start();
    recorder.speak(List.filled(8000, 50));
    await pumpAudio();
    activity.value = false;
    await recording.cancel();
    expect(files, isEmpty);
    expect(recorder.recording, isFalse);
    activity.dispose();
  });

  test('cancellation while saving never attaches to a new chat', () async {
    final gate = Completer<Directory>();
    create(cache: () => gate.future);
    await recording.start();
    recorder.speak(List.filled(8000, 80));
    await pumpAudio();
    final finishing = recording.finish();
    await pumpAudio();
    final cancelling = recording.cancel();
    gate.complete(directory);
    await finishing;
    await cancelling;
    expect(files, isEmpty);
  });

  test('CallKit audio acquisition waits for recording to stop', () async {
    create();
    await recording.start();
    recorder.speak(List.filled(8000, 90));
    await pumpAudio();
    final call = Object();
    await focus.acquire(call);
    expect(recorder.recording, isFalse);
    expect(files, isEmpty);
    await recording.start();
    expect(recorder.starts, 1);
    focus.release(call);
  });

  test(
    'disposal removes owned draft files after closing the microphone',
    () async {
      create();
      await recording.start();
      recorder.speak(List.filled(8000, 99));
      await pumpAudio();
      await recording.finish();
      final file = File(files.single.path);
      recording.dispose();
      await recording.whenClosed;
      expect(await file.exists(), isFalse);
      // teardown uses a fresh idle controller.
      create();
    },
  );
}
