import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_voice_recorder.dart';
import 'support/pump_chat.dart';

final _dictate = find.bySemanticsLabel('Dictate');

FakeHermesServer _server({bool voice = true}) {
  final server = FakeHermesServer()
    ..on('GET', '/api/sessions', sessionListBody(const []))
    ..on('POST', '/api/audio/stt-lease', {'ok': true})
    ..on('POST', '/api/audio/transcribe', {
      'ok': true,
      'transcript': 'book a table',
    });
  if (voice) {
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
}
