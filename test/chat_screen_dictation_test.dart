import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/voice/on_device_speech.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_speech_channel.dart';
import 'support/fake_voice_recorder.dart';
import 'support/pump_chat.dart';

final _dictate = find.bySemanticsLabel('Dictate');

FakeHermesServer _server({bool voice = true, bool sttDisabled = false}) {
  final server = FakeHermesServer()
    ..on('GET', '/api/sessions', sessionListBody(const []))
    ..on('POST', '/api/audio/stt-lease', {'ok': true})
    ..on('POST', '/api/audio/transcribe', {
      'ok': true,
      'transcript': 'book a table',
    });
  if (sttDisabled) {
    server.on('GET', '/api/audio/voice-config', {
      'ok': true,
      'stt': {'mode': 'relay', 'reason': 'stt disabled'},
      'tts': {'mode': 'relay'},
    });
  } else if (voice) {
    server.on('GET', '/api/audio/voice-config', {
      'ok': true,
      'stt': {'mode': 'relay', 'reason': 'local provider'},
      'tts': {'mode': 'relay'},
    });
  } else {
    server.on('GET', '/api/audio/voice-config', {
      'detail': 'Not Found',
    }, status: 404);
  }
  return server;
}

String _draft(WidgetTester tester) =>
    tester.widget<EditableText>(composerField).controller.text;

void main() {
  testWidgets('offers the microphone when the profile can transcribe', (
    tester,
  ) async {
    await pumpChatScreen(
      tester,
      server: _server(),
      voiceRecorder: FakeVoiceRecorder(),
    );

    expect(_dictate, findsOneWidget);
  });

  testWidgets('an older server without voice routes has no microphone', (
    tester,
  ) async {
    await pumpChatScreen(
      tester,
      server: _server(voice: false),
      voiceRecorder: FakeVoiceRecorder(),
    );

    expect(_dictate, findsNothing);
  });

  testWidgets('a transcript is added to the draft and not sent', (
    tester,
  ) async {
    final server = _server();
    final recorder = FakeVoiceRecorder();
    await pumpChatScreen(tester, server: server, voiceRecorder: recorder);
    await tester.enterText(composerField, 'Please');

    await tester.tap(_dictate);
    await tester.pump(const Duration(milliseconds: 300));
    recorder.speak(List.filled(160, 4000));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('Stop voice input'));
    await tester.pumpAndSettle();

    expect(_draft(tester), 'Please book a table');
    expect(server.requestsTo('POST', '/api/audio/transcribe'), hasLength(1));
    expect(find.text('book a table'), findsNothing, reason: 'nothing was sent');
  });

  testWidgets('leaving the app drops the recording', (tester) async {
    final server = _server();
    final recorder = FakeVoiceRecorder();
    await pumpChatScreen(tester, server: server, voiceRecorder: recorder);

    await tester.tap(_dictate);
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(recorder.recording, isFalse);
    expect(server.requestsTo('POST', '/api/audio/transcribe'), isEmpty);
    expect(composerField, findsOneWidget);
  });

  group('on the device', () {
    late FakeSpeechChannel speech;
    late DictationSettings settings;
    late OnDeviceSpeech onDevice;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      speech = FakeSpeechChannel();
      settings = DictationSettings();
      onDevice = OnDeviceSpeech();
    });
    tearDown(() => speech.dispose());

    Future<FakeHermesServer> pump(
      WidgetTester tester, {
      DictationEngine engine = DictationEngine.device,
      FakeVoiceRecorder? recorder,
      bool serverStt = false,
    }) async {
      final server = _server(sttDisabled: !serverStt);
      unawaited(settings.setEngine(engine));
      await pumpChatScreen(
        tester,
        server: server,
        voiceRecorder: recorder ?? FakeVoiceRecorder(),
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider.value(value: onDevice),
        ],
      );
      return server;
    }

    testWidgets('offers the microphone without a server provider', (
      tester,
    ) async {
      final server = await pump(tester);

      expect(_dictate, findsOneWidget);
      expect(server.requestsTo('GET', '/api/audio/voice-config'), isEmpty);
    });

    testWidgets('a saved device engine never reads the voice config', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final prefs = SharedPreferencesAsync();
      settings = DictationSettings(prefs: prefs);
      final server = _server(sttDisabled: true);
      await pumpChatScreen(
        tester,
        server: server,
        voiceRecorder: FakeVoiceRecorder(),
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider.value(value: onDevice),
        ],
      );
      await tester.runAsync(
        () => prefs.setString('hermes.dictation_engine', 'device'),
      );
      await tester.runAsync(settings.load);
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', '/api/audio/voice-config'), isEmpty);
      expect(_dictate, findsOneWidget);
    });

    testWidgets('hides the microphone while the model is missing', (
      tester,
    ) async {
      speech.status = 'missing';
      await pump(tester);

      expect(_dictate, findsNothing);
    });

    testWidgets('switching the engine checks again', (tester) async {
      await pump(tester, engine: DictationEngine.hermes);
      expect(_dictate, findsNothing, reason: 'the server has no STT');

      unawaited(settings.setEngine(DictationEngine.device));
      await tester.pumpAndSettle();

      expect(_dictate, findsOneWidget);
    });

    testWidgets('downloads a missing model without a tap', (tester) async {
      speech.status = 'missing';
      await pump(tester);
      expect(_dictate, findsNothing);
      expect(speech.methods, contains('install'));

      speech.completeInstall();
      await tester.pumpAndSettle();

      expect(_dictate, findsOneWidget);
      expect(speech.methods.where((m) => m == 'install'), hasLength(1));
    });

    testWidgets('a failed download keeps the microphone hidden', (
      tester,
    ) async {
      speech.status = 'missing';
      final server = await pump(tester, serverStt: true);

      speech.failInstall('failed');
      await tester.pumpAndSettle();

      expect(_dictate, findsNothing);
      expect(server.requestsTo('GET', '/api/audio/voice-config'), isEmpty);
    });

    testWidgets('falls back to Hermes where the device cannot recognize', (
      tester,
    ) async {
      speech.status = 'unsupported';
      final server = await pump(tester, serverStt: true);

      expect(_dictate, findsOneWidget);
      expect(server.requestsTo('GET', '/api/audio/voice-config'), hasLength(1));
      expect(speech.methods, isNot(contains('install')));
    });

    Future<FakeVoiceRecorder> startDictating(WidgetTester tester) async {
      final recorder = FakeVoiceRecorder();
      await pump(tester, recorder: recorder);
      await tester.enterText(composerField, 'Please');
      await tester.tap(_dictate);
      await tester.pump(const Duration(milliseconds: 300));
      recorder.speak(List.filled(160, 4000));
      await tester.pump(const Duration(milliseconds: 300));
      return recorder;
    }

    testWidgets('the words appear in the field as they are heard', (
      tester,
    ) async {
      await startDictating(tester);

      await tester.runAsync(() async {
        speech.hears('book a');
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump();

      expect(_draft(tester), 'Please book a');
    });

    testWidgets('cancel gives the draft back', (tester) async {
      await startDictating(tester);
      await tester.runAsync(() async {
        speech.hears('book a');
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Cancel voice input'));
      await tester.pumpAndSettle();

      expect(_draft(tester), 'Please');
    });

    testWidgets('send while recording sends the draft with the transcript', (
      tester,
    ) async {
      speech.transcript = 'book a table';
      await startDictating(tester);

      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Please book a table'), findsWidgets);
      expect(_draft(tester), isEmpty);
    });

    testWidgets('send after a failed transcription sends nothing', (
      tester,
    ) async {
      speech.finishError = 'failed';
      await startDictating(tester);

      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();

      expect(_draft(tester), 'Please');
      expect(find.text('Couldn’t transcribe the recording.'), findsOneWidget);
    });

    testWidgets('dictates into the draft without asking the server', (
      tester,
    ) async {
      speech.transcript = 'book a table';
      final recorder = FakeVoiceRecorder();
      final server = await pump(tester, recorder: recorder);
      await tester.enterText(composerField, 'Please');

      await tester.tap(_dictate);
      await tester.pump(const Duration(milliseconds: 300));
      recorder.speak(List.filled(160, 4000));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.bySemanticsLabel('Stop voice input'));
      await tester.pumpAndSettle();

      expect(_draft(tester), 'Please book a table');
      expect(
        server.requests.where((r) => r.path.startsWith('/api/audio/')),
        isEmpty,
      );
    });
  });
}
