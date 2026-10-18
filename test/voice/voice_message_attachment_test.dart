import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/voice_message_attachment.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/voice_playback.dart';
import 'package:hermes_app/src/voice/voice_playback_scope.dart';
import 'package:hermes_app/src/voice/widgets/voice_message_view.dart';
import 'package:provider/provider.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/fake_voice_player.dart';

void main() {
  late FakeHermesServer server;
  late MediaStore store;
  late FakeVoicePlayer player;
  late VoicePlayback playback;
  late Directory cache;
  late FakeMediaActions actions;
  const audio = ChatAttachment(
    name: 'voice.ogg',
    kind: AttachmentKind.file,
    remotePath: '/srv/voice.ogg',
  );
  final bytes = Uint8List.fromList('OggS synthetic clip'.codeUnits);

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/files/download',
        bytes,
        query: {'path': '/srv/voice.ogg'},
      );
    cache = tempDir('voice_message');
    actions = FakeMediaActions();
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: actions,
    );
    player = FakeVoicePlayer();
    playback = VoicePlayback(createPlayer: () => player);
  });
  tearDown(() {
    playback.dispose();
    store.dispose();
  });

  test(
    'reopened history recognizes both file references and TTS delivery tags',
    () async {
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: '@file:/srv/voice.ogg'),
          messageRow(
            id: 2,
            role: 'assistant',
            content: '[[audio_as_voice]]\nMEDIA:/srv/reply.mp3',
          ),
        ]),
      );
      final messages = await HermesChatRepository(server.client().raw)
          .loadMessages('s1');
      final files = messages
          .expand(chatMessageToFlyer)
          .whereType<FileMessage>()
          .toList();
      expect(files, hasLength(2));
      expect(
        files.map(
          (file) => (file.metadata![kMetaAttachment] as ChatAttachment).isAudio,
        ),
        everyElement(isTrue),
      );
      expect(files.map((file) => file.source), [
        '/srv/voice.ogg',
        '/srv/reply.mp3',
      ]);
    },
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MediaStore?>.value(value: store),
          ChangeNotifierProvider.value(value: playback),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );
  }

  Future<void> tapAndWait(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip(label));
      for (
        var i = 0;
        i < 50 && (playback.loading || player.loaded.isEmpty);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'plays a downloaded OGG in the client, with pause, seek and save',
    (tester) async {
      await pump(
        tester,
        const VoiceMessageAttachment(attachment: audio, messageId: 'a'),
      );
      expect(server.requestsTo('GET', '/api/files/download'), isEmpty);
      await tapAndWait(tester, 'Play voice message');
      expect(playback.playing, isTrue);
      expect(player.loaded.single, startsWith(cache.path));
      expect(File(player.loaded.single).readAsBytesSync(), bytes);
      expect(actions.opened, isEmpty);
      expect(find.text('0:00 / 0:48'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      await tester.runAsync(() async => slider.onChanged!(12000));
      await tester.pump();
      expect(player.position, const Duration(seconds: 12));
      await tapAndWait(tester, 'Pause voice message');
      expect(playback.playing, isFalse);
      await tapAndWait(tester, 'Play voice message');
      expect(server.requestsTo('GET', '/api/files/download'), hasLength(1));
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Save voice message'));
        for (var i = 0; i < 50 && actions.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(actions.saved.single.name, 'voice.ogg');
      expect(actions.saved.single.bytes, bytes);
    },
  );

  testWidgets('a server failure offers retry and then plays', (tester) async {
    server.on(
      'GET',
      '/api/files/download',
      {'detail': 'offline'},
      status: 503,
      query: {'path': '/srv/voice.ogg'},
    );
    await pump(
      tester,
      const VoiceMessageAttachment(attachment: audio, messageId: 'a'),
    );
    await tapAndWait(tester, 'Play voice message');
    expect(
      find.text('Could not download the audio. Tap to try again.'),
      findsOneWidget,
    );
    server.on(
      'GET',
      '/api/files/download',
      bytes,
      query: {'path': '/srv/voice.ogg'},
    );
    await tapAndWait(tester, 'Retry voice message');
    expect(playback.playing, isTrue);
    expect(server.requestsTo('GET', '/api/files/download'), hasLength(2));
  });

  testWidgets('embedded audio plays and saves without asking the server', (
    tester,
  ) async {
    await pump(
      tester,
      VoiceMessageAttachment(
        attachment: ChatAttachment(
          name: 'voice.mp3',
          kind: AttachmentKind.file,
          bytes: bytes,
        ),
        messageId: 'a',
      ),
    );
    await tapAndWait(tester, 'Play voice message');
    expect(playback.playing, isTrue);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save voice message'));
      for (var i = 0; i < 50 && actions.saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(actions.saved.single.bytes, bytes);
    expect(server.requestsTo('GET', '/api/files/download'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('live and completed Hermes voice tags render the same player', (
    tester,
  ) async {
    List<Message> messages(MessageStatus status, String content) =>
        chatMessageToFlyer(
          ChatMessage(
            id: 'reply',
            role: ChatRole.assistant,
            createdAt: DateTime.utc(2026),
            content: content,
            status: status,
          ),
        );
    final chat = InMemoryChatController(
      messages: messages(
        MessageStatus.streaming,
        '[[audio_as_voice]]\nMEDIA:/srv/voice.o',
      ),
    );
    addTearDown(chat.dispose);
    await pump(
      tester,
      Chat(
        currentUserId: 'user',
        chatController: chat,
        resolveUser: (id) async => User(id: id),
        builders: buildChatBuilders(onPickPrompt: (_) {})
            .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VoiceMessageView), findsNothing);
    await chat.setMessages(
      messages(
        MessageStatus.streaming,
        '[[audio_as_voice]]\nMEDIA:/srv/voice.ogg\n',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VoiceMessageView), findsOneWidget);
    await chat.setMessages(
      messages(MessageStatus.sent, '[[audio_as_voice]]\nMEDIA:/srv/voice.ogg'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VoiceMessageView), findsOneWidget);
    expect(find.textContaining('[[audio_as_voice]]'), findsNothing);
    expect(server.requestsTo('GET', '/api/files/download'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'leaving the app pauses audio and removing the transcript releases it',
    (tester) async {
      VoicePlayback? scoped;
      await pump(
        tester,
        VoicePlaybackScope(
          createPlayer: () => player,
          child: Builder(
            builder: (context) {
              scoped = context.read<VoicePlayback>();
              return const SizedBox();
            },
          ),
        ),
      );
      await scoped!.toggle('a', () async => File('/cache/a.ogg'));
      expect(player.playing, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(player.playing, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(player.playing, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(player.disposed, isTrue);
    },
  );
}
