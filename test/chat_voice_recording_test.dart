import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_voice_recorder.dart';
import 'support/pump_chat.dart';
import 'support/screenshot_recorder.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes_record_screen_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });

  Future<void> frames(WidgetTester tester, [int count = 10]) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'hold, release to attach, short tap sends audio with typed text (${dark ? 'dark' : 'light'})',
      (tester) async {
        final shots = ScreenshotRecorder(
          'voice-recording-${dark ? 'dark' : 'light'}',
        );
        await shots.start(tester, phoneSize);
        final recorder = FakeVoiceRecorder();
        final transport = FakeChatTransport();
        final server = FakeHermesServer()
          ..on('GET', '/api/sessions', sessionListBody(const []));
        await pumpChatScreen(
          tester,
          server: server,
          transport: transport,
          voiceMessageRecorder: recorder,
          size: const Size(390, 844),
          platform: TargetPlatform.iOS,
          wrap: shots.frame,
          theme: withScreenshotFont(
            dark
                ? buildHermesDarkTheme(platform: TargetPlatform.iOS)
                : buildHermesLightTheme(platform: TargetPlatform.iOS),
          ),
        );
        await tester.tap(find.bySemanticsLabel('New message'));
        await tester.pumpAndSettle();
        await tester.enterText(composerField, 'Listen to this');
        final hold = await tester.startGesture(
          tester.getCenter(find.bySemanticsLabel('Send')),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await frames(tester, 2);
        expect(recorder.recording, isTrue);
        recorder.speak(List.filled(8000, 1000));
        await frames(tester, 2);
        expect(find.textContaining('Release to attach'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(transport.sends, isEmpty);
        await shots.capture(tester, 'recording');
        await hold.up();
        await frames(tester);
        expect(recorder.recording, isFalse);
        expect(transport.sends, isEmpty, reason: 'release must not send');
        expect(
          find.widgetWithText(InputChip, 'Voice message 1s.wav'),
          findsOneWidget,
        );
        expect(
          tester.widget<EditableText>(composerField).controller.text,
          'Listen to this',
        );
        await shots.capture(tester, 'attached');
        await tester.tap(find.bySemanticsLabel('Send'));
        await frames(tester);
        expect(transport.sends, hasLength(1));
        final send = transport.sends.single;
        expect(send.text, 'Listen to this');
        expect(send.attachments.single.mimeType, 'audio/wav');
        final audio = await tester.runAsync(send.attachments.single.read);
        expect(String.fromCharCodes(audio!.take(4)), 'RIFF');
        expect(find.byType(InputChip), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await frames(tester);
      },
    );
  }

  testWidgets(
    'an empty draft records, cancellation discards, short tap never records',
    (tester) async {
      final recorder = FakeVoiceRecorder();
      final transport = FakeChatTransport();
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions', sessionListBody(const []));
      await pumpChatScreen(
        tester,
        server: server,
        transport: transport,
        voiceMessageRecorder: recorder,
      );
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pump();
      expect(recorder.starts, 0);
      final hold = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Send')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await frames(tester, 2);
      expect(recorder.recording, isTrue);
      recorder.speak(List.filled(8000, 200));
      await frames(tester, 2);
      await hold.cancel();
      await frames(tester);
      expect(recorder.recording, isFalse);
      expect(find.byType(InputChip), findsNothing);
      expect(transport.sends, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
    },
  );

  testWidgets('voice attachment can be removed without sending', (
    tester,
  ) async {
    final recorder = FakeVoiceRecorder();
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody(const []));
    await pumpChatScreen(
      tester,
      server: server,
      voiceMessageRecorder: recorder,
    );
    final hold = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Send')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await frames(tester, 2);
    recorder.speak(List.filled(8000, 200));
    await frames(tester, 2);
    await hold.up();
    await frames(tester);
    expect(find.byType(InputChip), findsOneWidget);
    final chip = tester.widget<InputChip>(find.byType(InputChip));
    chip.onDeleted!();
    await tester.pump();
    expect(find.byType(InputChip), findsNothing);
    expect(
      tester.widget<ChatComposer>(find.byType(ChatComposer)).attachments,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await frames(tester);
  });
  testWidgets('backgrounding discards audio and preserves typed text', (
    tester,
  ) async {
    final recorder = FakeVoiceRecorder();
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody(const []));
    await pumpChatScreen(
      tester,
      server: server,
      voiceMessageRecorder: recorder,
    );
    await tester.enterText(composerField, 'Keep this draft');
    final hold = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Send')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await frames(tester, 2);
    recorder.speak(List.filled(8000, 200));
    await frames(tester, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await frames(tester);
    await hold.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    expect(recorder.recording, isFalse);
    expect(find.byType(InputChip), findsNothing);
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Keep this draft',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await frames(tester);
  });
}
