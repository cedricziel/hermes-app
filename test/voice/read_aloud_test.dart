import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/read_aloud_actions.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/read_aloud.dart';
import 'package:hermes_app/src/voice/synthesized_speech.dart';
import 'package:hermes_app/src/voice/voice_audio_focus.dart';
import 'package:hermes_app/src/voice/voice_playback.dart';
import 'package:provider/provider.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/fake_voice_player.dart';

void main() {
  group('speakableText', () {
    test('keeps the words and drops the markdown marks', () {
      expect(
        speakableText(
          '# Done\n\n'
          'The **build** passed, see [the log](https://ci/1) and _notes_.\n'
          '- first `step`\n'
          '* [x] second\n'
          '> quoted\n'
          '---\n'
          '```bash\nmake test\n```\n'
          '| a | b |\n|---|---|\n| 1 | 2 |\n'
          '![chart](https://img)',
        ),
        'Done\n\n'
        'The build passed, see the log and notes.\n'
        'first step\n'
        'second\n'
        'quoted\n'
        'make test\n'
        '  a   b  \n'
        '  1   2  \n'
        'chart',
      );
    });

    test('keeps words with underscores and plain asterisks', () {
      expect(
        speakableText('snake_case_name is 2 * 3'),
        'snake_case_name is 2 * 3',
      );
    });

    test('reads code as written and only matching marks as emphasis', () {
      expect(speakableText('Call `__init__` first'), 'Call __init__ first');
      expect(
        speakableText('Use `*` or `_` as wildcard'),
        'Use * or _ as wildcard',
      );
      expect(speakableText('a *b_ c'), 'a *b_ c');
      expect(
        speakableText('```py\ndef __init__(self): **x**\n```'),
        'def __init__(self): **x**',
      );
    });

    test('links with parentheses, escapes and pipes outside tables', () {
      expect(speakableText('see [docs](https://x/(a)) now'), 'see docs now');
      expect(speakableText(r'Escaped \*stars\*'), 'Escaped *stars*');
      expect(speakableText('a || b'), 'a || b');
    });

    test('a reply of marks only has nothing to say', () {
      expect(speakableText('```\n```\n---'), isEmpty);
    });
  });

  test('audio types get the extension the player expects', () {
    expect(audioExtension('audio/mpeg'), 'mp3');
    expect(audioExtension('audio/ogg'), 'ogg');
    expect(audioExtension('audio/x-wav'), 'wav');
    expect(audioExtension('audio/flac'), 'flac');
    expect(audioExtension('audio/unknown'), 'audio');
  });

  group('with a cache', () {
    late Directory cache;
    late MediaStore store;
    late FakeHermesServer server;

    setUp(() {
      cache = tempDir('read_aloud');
      server = FakeHermesServer();
      store = MediaStore(
        source: HermesMediaSource(() => server.client()),
        cacheDirectory: () async => cache,
        actions: FakeMediaActions(),
      );
    });
    tearDown(() => store.dispose());

    test("fetch speaks the reply's words with the profile's voice", () async {
      final audio = Uint8List.fromList('ID3 synthetic speech'.codeUnits);
      server.on('POST', '/api/audio/speak', {
        'ok': true,
        'data_url': 'data:audio/mpeg;base64,${base64Encode(audio)}',
      });
      final repository = HermesChatRepository(server.client().raw);
      final readAloud = ReadAloud(
        profile: 'work',
        store: store,
        synthesize: (text, cancellation) => repository.synthesize(
          text,
          profile: 'work',
          cancellation: cancellation,
        ),
      );

      final file = await readAloud.fetch('The **build** passed.');

      expect(file.path, startsWith(cache.path));
      expect(file.path, endsWith('.mp3'));
      expect(file.readAsBytesSync(), audio);
      final request = server.requestsTo('POST', '/api/audio/speak').single;
      expect(request.queryParameters['profile'], 'work');
      expect(jsonBody(request), {'text': 'The build passed.'});

      // The same words again are not spoken again, nor are they after
      // something else played in between.
      expect((await readAloud.fetch('The build passed.')).path, file.path);
      expect(server.requestsTo('POST', '/api/audio/speak'), hasLength(1));
    });

    test('cancel abandons speech Hermes is still making', () async {
      final tokens = <CancelToken>[];
      final readAloud = ReadAloud(
        profile: null,
        store: store,
        synthesize: (text, cancellation) {
          tokens.add(cancellation);
          return Completer<SynthesizedSpeech>().future;
        },
      );
      unawaited(readAloud.fetch('First.'));
      await Future<void>.delayed(Duration.zero);
      expect(tokens.single.isCancelled, isFalse);

      unawaited(readAloud.fetch('Second.'));
      await Future<void>.delayed(Duration.zero);
      expect(tokens.first.isCancelled, isTrue, reason: 'a newer fetch wins');

      readAloud.cancel();
      expect(tokens.last.isCancelled, isTrue);
    });

    group('the action', () {
      late FakeVoicePlayer player;
      late VoicePlayback playback;
      late List<String> spoken;
      late bool failSpeech;

      setUp(() {
        player = FakeVoicePlayer();
        playback = VoicePlayback(createPlayer: () => player);
        spoken = [];
        failSpeech = false;
      });
      tearDown(() => playback.dispose());

      ReadAloud readAloud() => ReadAloud(
        profile: null,
        store: store,
        synthesize: (text, _) async {
          spoken.add(text);
          if (failSpeech) throw StateError('no provider');
          return SynthesizedSpeech(
            Uint8List.fromList('OggS speech'.codeUnits),
            'audio/ogg',
          );
        },
      );

      Future<void> pump(
        WidgetTester tester, {
        required ReadAloud? readAloud,
        String text = 'The build passed.',
      }) => tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ReadAloud?>.value(value: readAloud),
            ChangeNotifierProvider.value(value: playback),
          ],
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            home: Scaffold(
              body: ReadAloudActions(
                messageId: 'reply',
                text: text,
                builder: (state, onReadAloud) => MessageActions(
                  text: text,
                  readAloud: state,
                  onReadAloud: onReadAloud,
                ),
              ),
            ),
          ),
        ),
      );

      Future<void> tapAndWait(WidgetTester tester, String label) async {
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip(label));
          for (var i = 0; i < 100; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            if (!playback.loading) break;
          }
        });
        await tester.pump();
      }

      testWidgets('is hidden without text to speech or words', (tester) async {
        await pump(tester, readAloud: null);
        expect(find.byTooltip('Read aloud'), findsNothing);
        expect(find.byTooltip('Copy'), findsOneWidget);
        await pump(tester, readAloud: readAloud(), text: '---');
        expect(find.byTooltip('Read aloud'), findsNothing);
      });

      testWidgets('plays the reply, shows it, and stops', (tester) async {
        await pump(tester, readAloud: readAloud());
        await tapAndWait(tester, 'Read aloud');

        expect(spoken, ['The build passed.']);
        expect(player.loaded.single, endsWith('.ogg'));
        expect(player.playing, isTrue);
        expect(find.byTooltip('Stop reading'), findsOneWidget);

        await tapAndWait(tester, 'Stop reading');
        expect(player.playing, isFalse);
        expect(player.seeks.last, Duration.zero);
        expect(find.byTooltip('Read aloud'), findsOneWidget);

        // Starting again plays the same audio from the start.
        await tapAndWait(tester, 'Read aloud');
        expect(spoken, hasLength(1));
        expect(player.playing, isTrue);
      });

      testWidgets('says when Hermes could not speak', (tester) async {
        failSpeech = true;
        await pump(tester, readAloud: readAloud());
        await tapAndWait(tester, 'Read aloud');
        await tester.pump();

        expect(player.playing, isFalse);
        expect(
          find.text("Couldn't read this reply aloud. Try again."),
          findsOneWidget,
        );
        expect(find.byTooltip('Read aloud'), findsOneWidget);
      });

      testWidgets('is disabled during a voice call', (tester) async {
        final call = Object();
        await tester.runAsync(() => VoiceAudioFocus.shared.acquire(call));
        addTearDown(() => VoiceAudioFocus.shared.release(call));
        await pump(tester, readAloud: readAloud());
        final button = tester.widget<IconButton>(
          find.descendant(
            of: find.byTooltip('Read aloud'),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.onPressed, isNull);
      });
    });

    testWidgets('a finished reply in the transcript offers Read aloud', (
      tester,
    ) async {
      final chat = InMemoryChatController(
        messages: [
          Message.text(
            id: 'reply',
            authorId: kAssistantAuthorId,
            text: 'The build passed.',
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
      addTearDown(chat.dispose);
      await tester.pumpWidget(
        Provider<ReadAloud?>.value(
          value: ReadAloud(
            profile: null,
            store: store,
            synthesize: (_, _) => throw UnimplementedError(),
          ),
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            home: Scaffold(
              body: Chat(
                currentUserId: kUserAuthorId,
                resolveUser: (id) async => User(id: id),
                chatController: chat,
                builders: buildChatBuilders(onPickPrompt: (_) {})
                    .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Read aloud'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
