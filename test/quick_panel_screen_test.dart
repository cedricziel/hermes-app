import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/quick_panel/quick_panel_screen.dart';
import 'package:hermes_app/src/quick_panel/widgets/quick_panel_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_attachment_source.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_voice_recorder.dart';
import 'support/pump_chat.dart' show composerField;

class _FakePanelLink implements QuickPanelLink {
  String? profile = 'work';
  final calls = <String>[];
  final heights = <double>[];
  final chats = <bool>[];
  final shownIn = StreamController<void>.broadcast(sync: true);
  final hiddenIn = StreamController<void>.broadcast(sync: true);
  ({String threadId, String? profile, String title, String? draft})? opened;

  void dispose() {
    shownIn.close();
    hiddenIn.close();
  }

  @override
  Stream<void> get shown => shownIn.stream;

  @override
  Stream<void> get hidden => hiddenIn.stream;

  @override
  Future<void> present() async => calls.add('present');

  @override
  Future<void> hide(String reason) async {
    calls.add('hide:$reason');
    hiddenIn.add(null);
  }

  @override
  Future<void> resize(double height) async => heights.add(height);

  @override
  Future<String?> currentProfile() async => profile;

  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};

  @override
  Future<void> showInWindow({
    required String threadId,
    required String? profile,
    required String title,
    ConversationDraft? draft,
  }) async {
    calls.add('showInWindow');
    opened = (
      threadId: threadId,
      profile: profile,
      title: title,
      draft: draft?.text,
    );
  }

  @override
  void reportChat({required bool continued}) => chats.add(continued);
}

void main() {
  late FakeHermesServer server;
  late _FakePanelLink link;
  late FakeChatTransport transport;
  late FakeVoiceRecorder recorder;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody(const []))
      ..on('POST', '/api/audio/stt-lease', {'ok': true})
      ..on('GET', '/api/audio/voice-config', {
        'ok': true,
        'stt': {'mode': 'relay', 'reason': 'local provider'},
        'tts': {'mode': 'relay'},
      })
      ..on('GET', '/api/model/options', {'detail': 'boom'}, status: 500);
    link = _FakePanelLink();
    transport = FakeChatTransport();
    recorder = FakeVoiceRecorder();
    addTearDown(link.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(680, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = server.client().raw;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: QuickPanelScreen(
          link: link,
          chat: HermesChatRepository(api),
          models: HermesModelsRepository(api),
          transport: transport,
          attachmentSource: FakeAttachmentSource(),
          voiceRecorder: recorder,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> show(WidgetTester tester) async {
    link.shownIn.add(null);
    await tester.pumpAndSettle();
  }

  Future<FakeSend> ask(WidgetTester tester, String text) async {
    await tester.enterText(composerField, text);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    return transport.sends.last;
  }

  testWidgets('Return sends on the current profile and the reply streams', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    expect(link.calls, contains('present'));

    final send = await ask(tester, 'What is due today?');
    expect(send.profile, 'work');
    expect(send.threadId, isNull);
    send
      ..emit(const ThreadBound('s9'))
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('Two reviews'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Two reviews'), findsOneWidget);
    expect(link.heights.last, QuickPanelView.expandedHeight);
    final sessions = server.requestsTo('GET', '/api/sessions').single;
    expect(sessions.queryParameters['profile'], 'work');
  });

  testWidgets('a show within five minutes continues, a later one is empty', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 10, 12);
    await withClock(Clock(() => now), () async {
      await pump(tester);
      await show(tester);
      final send = await ask(tester, 'What is due today?');
      send
        ..emit(const ThreadBound('s9'))
        ..emit(const ReplyCompleted('Two reviews'));
      await tester.pumpAndSettle();

      now = now.add(const Duration(minutes: 2));
      await show(tester);
      expect(find.textContaining('Two reviews'), findsOneWidget);

      now = now.add(const Duration(minutes: 6));
      await show(tester);
      expect(find.textContaining('Two reviews'), findsNothing);
      expect(link.chats, [false, true, false]);
    });
  });

  testWidgets('a show on another profile starts empty and sends there', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    (await ask(tester, 'Hi'))
      ..emit(const ThreadBound('s9'))
      ..emit(const ReplyCompleted('Hello'));
    await tester.pumpAndSettle();

    link.profile = 'home';
    await show(tester);

    expect(find.textContaining('Hello'), findsNothing);
    expect((await ask(tester, 'Again')).profile, 'home');
  });

  testWidgets('Escape cancels a dictation first, then hides the panel', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    await tester.tap(find.bySemanticsLabel('Dictate'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(link.calls, isNot(contains('hide:escape')));
    expect(find.bySemanticsLabel('Stop voice input'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(link.calls, contains('hide:escape'));
  });

  testWidgets('the model pill stays away when the options fail', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);

    expect(find.byKey(const Key('composer-model-pill')), findsNothing);
    expect(
      link.heights.single,
      lessThan(QuickPanelView.expandedHeight),
      reason: 'before the first send the panel fits the composer',
    );
    expect((await ask(tester, 'Still sends')).text, 'Still sends');
  });

  testWidgets('Open in Hermes hides the panel, then moves the chat', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    (await ask(tester, 'Plan the trip'))
      ..emit(const ThreadBound('s9'))
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('Lisbon'));
    await tester.pumpAndSettle();
    await tester.enterText(composerField, 'and Porto?');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(link.calls.where((c) => c != 'present'), [
      'hide:open_in_hermes',
      'showInWindow',
    ]);
    expect(link.opened?.threadId, 's9');
    expect(link.opened?.profile, 'work');
    expect(link.opened?.draft, 'and Porto?');

    await show(tester);
    expect(find.textContaining('Lisbon'), findsNothing);
    expect(link.chats.last, isFalse);
  });

  testWidgets('Open in Hermes waits for a saved chat', (tester) async {
    await pump(tester);
    await show(tester);

    await tester.tap(find.text('Open in Hermes'));
    await tester.pump();

    expect(link.calls, isNot(contains('showInWindow')));
  });
}
