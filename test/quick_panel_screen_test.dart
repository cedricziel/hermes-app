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
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_attachment_source.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_voice_recorder.dart';
import 'support/pump_chat.dart' show composerField;

const _readyModels = {
  'provider': 'nous',
  'model': 'hermes-4',
  'providers': [
    {
      'slug': 'nous',
      'authenticated': true,
      'models': ['hermes-4'],
    },
  ],
};

class _FakePanelLink implements QuickPanelLink {
  String? profile = 'work';
  final calls = <String>[];
  final heights = <double>[];
  final chats = <bool>[];
  final shownIn = StreamController<void>.broadcast(sync: true);
  final hiddenIn = StreamController<void>.broadcast(sync: true);
  final commandsIn = StreamController<String>.broadcast(sync: true);
  final holds = <bool>[];
  var dictatingReports = 0;
  WindowMove move = WindowMove.opened;
  ({String threadId, String? profile, String title, String? draft})? opened;

  void dispose() {
    shownIn.close();
    hiddenIn.close();
    commandsIn.close();
  }

  @override
  Stream<String> get commands => commandsIn.stream;

  @override
  Future<void> hold(bool held) async => holds.add(held);

  @override
  void reportDictating() => dictatingReports++;

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
  Future<WindowMove> showInWindow({
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
    return move;
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
      ..on('GET', '/api/model/options', _readyModels)
      ..on('GET', '/api/sessions/s9', sessionRow(id: 's9', title: 'Today'))
      ..on(
        'GET',
        '/api/sessions/s9/messages',
        messageListBody('s9', [
          messageRow(id: 1, role: 'user', content: 'What is due today?'),
          messageRow(id: 2, role: 'assistant', content: 'Two reviews'),
        ]),
      );
    link = _FakePanelLink();
    transport = FakeChatTransport();
    recorder = FakeVoiceRecorder();
    addTearDown(link.dispose);
  });

  Future<void> pump(
    WidgetTester tester, {
    double height = 540,
    DictationSettings? dictationSettings,
  }) async {
    tester.view.physicalSize = Size(680, height);
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
          dictationSettings: dictationSettings,
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

  testWidgets('failed model discovery keeps the draft and offers Retry', (
    tester,
  ) async {
    server.on('GET', '/api/model/options', {'detail': 'boom'}, status: 500);
    await pump(tester);
    await show(tester);
    await tester.enterText(composerField, 'Still here');
    await tester.pump();

    expect(find.byKey(const Key('composer-model-pill')), findsOneWidget);
    expect(find.text('Could not load models'), findsOneWidget);
    expect(_sendEnabled(tester), isFalse);
    expect(link.heights.last, lessThan(QuickPanelView.expandedHeight));
    server.on('GET', '/api/model/options', _readyModels);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('hermes-4'), findsOneWidget);
    expect(_draft(tester), 'Still here');
    expect(transport.sends, isEmpty);
    expect((await ask(tester, 'Still here')).text, 'Still here');
  });

  testWidgets('pending model discovery keeps Send disabled until ready', (
    tester,
  ) async {
    final models = Completer<FakeResponse>();
    server.onRequest('GET', '/api/model/options', (_) => models.future);
    await pump(tester);
    await show(tester);
    await tester.enterText(composerField, 'Wait for the model');
    await tester.pump();

    expect(find.text('Loading models'), findsOneWidget);
    expect(_sendEnabled(tester), isFalse);
    models.complete((status: 200, body: _readyModels));
    await tester.pumpAndSettle();

    expect(_draft(tester), 'Wait for the model');
    expect(transport.sends, isEmpty);
    expect(_sendEnabled(tester), isTrue);
    expect((await ask(tester, 'Wait for the model')).profile, 'work');
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

  testWidgets('typing and Return during the first load keep the draft until '
      'a configured model is ready', (tester) async {
    final loaded = Completer<void>();
    server.onRequest('GET', '/api/sessions', (_) async {
      await loaded.future;
      return (status: 200, body: sessionListBody(const []));
    });
    await pump(tester);
    link.shownIn.add(null);
    await tester.pump();

    await tester.enterText(composerField, 'Quick one');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(transport.sends, isEmpty);
    expect(_draft(tester), 'Quick one');

    loaded.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(transport.sends, isEmpty);
    expect(_draft(tester), 'Quick one');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final send = transport.sends.single;
    expect((send.text, send.profile), ('Quick one', 'work'));
  });

  testWidgets('a failed load offers a retry and refuses to send', (
    tester,
  ) async {
    server.on('GET', '/api/sessions', {'detail': 'down'}, status: 500);
    await pump(tester);
    await show(tester);

    expect(find.text('Could not load your chats.'), findsOneWidget);
    await tester.enterText(composerField, 'Hello?');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(transport.sends, isEmpty);
    expect(_draft(tester), 'Hello?');

    server.on('GET', '/api/sessions', sessionListBody(const []));
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load your chats.'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(transport.sends.single.profile, 'work');
  });

  testWidgets('hiding during a dictation releases the microphone', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    await tester.tap(find.bySemanticsLabel('Dictate'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(recorder.recording, isTrue);
    expect(link.dictatingReports, 1);

    await link.hide('focus_lost');
    await tester.pumpAndSettle();

    expect(recorder.recording, isFalse);
  });

  testWidgets('the main window taking the microphone stops the panel\'s', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    await tester.tap(find.bySemanticsLabel('Dictate'));
    await tester.pump(const Duration(milliseconds: 300));

    link.commandsIn.add('stopDictation');
    await tester.pumpAndSettle();

    expect(recorder.recording, isFalse);
  });

  testWidgets('the draft stays across a hide that started nothing', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    await tester.enterText(composerField, 'half a thought');

    await link.hide('focus_lost');
    await show(tester);

    expect(_draft(tester), 'half a thought');
  });

  testWidgets('before the first send the panel grows with the prompt', (
    tester,
  ) async {
    await pump(tester, height: 168);
    await show(tester);
    final small = link.heights.last;

    await tester.enterText(composerField, List.filled(8, 'line').join('\n'));
    await tester.pumpAndSettle();

    expect(link.heights.last, greaterThan(small));
    expect(link.heights.last, greaterThan(168));
  });

  testWidgets('every show checks the connection', (tester) async {
    await pump(tester);
    await show(tester);
    await show(tester);

    expect(transport.connectionChecks, 2);
  });

  testWidgets('a show reads the Dictation setting again', (tester) async {
    final settings = DictationSettings();
    await pump(tester, dictationSettings: settings);
    await show(tester);
    await DictationSettings().setEngine(DictationEngine.device);

    await show(tester);

    expect(settings.engine, DictationEngine.device);
  });

  testWidgets('a chat a window already shows keeps the panel\'s draft', (
    tester,
  ) async {
    await pump(tester);
    await show(tester);
    (await ask(tester, 'Plan the trip'))
      ..emit(const ThreadBound('s9'))
      ..emit(const ReplyCompleted('Lisbon'));
    await tester.pumpAndSettle();
    await tester.enterText(composerField, 'and Porto?');
    link.move = WindowMove.focused;

    await tester.tap(find.text('Open in Hermes'));
    await tester.pumpAndSettle();

    expect(_draft(tester), 'and Porto?');
  });

  testWidgets('picking files holds the panel open', (tester) async {
    await pump(tester);
    await show(tester);

    await tester.tap(find.bySemanticsLabel('Add attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(link.holds, [true, false]);
  });
}

String _draft(WidgetTester tester) =>
    tester.widget<EditableText>(composerField).controller.text;

bool _sendEnabled(WidgetTester tester) =>
    tester
        .widget<IconButton>(
          find
              .descendant(
                of: find.byTooltip('Send'),
                matching: find.byType(IconButton),
              )
              .first,
        )
        .onPressed !=
    null;
