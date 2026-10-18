import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart' show FileMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/voice/voice_transcript.dart';

import '../support/fake_hermes_server.dart';

void main() {
  const audio = ChatAttachment(
    name: 'voice.ogg',
    kind: AttachmentKind.file,
    remotePath: '/srv/voice.ogg',
  );
  ToolCall tts({
    String path = '/srv/voice.ogg',
    bool success = true,
    Object? data,
    ToolCallStatus status = ToolCallStatus.completed,
  }) => ToolCall(
    name: 'text_to_speech',
    summary: 'Speak',
    status: status,
    args: const {'text': 'Here is your morning briefing.'},
    resultData: data ?? {'success': success, 'file_path': path},
  );

  test('uses the successful matching TTS input, not a caption or filename', () {
    expect(voiceTranscript(audio, [tts()]), 'Here is your morning briefing.');
    expect(voiceTranscript(audio, [tts(path: '/other/voice.ogg')]), isNull);
    expect(voiceTranscript(audio, [tts(success: false)]), isNull);
    expect(voiceTranscript(audio, [tts(status: ToolCallStatus.error)]), isNull);
    expect(voiceTranscript(audio, []), isNull);
  });

  test('matches legacy JSON results and media_tag results', () {
    final call = ToolCall(
      name: 'text_to_speech',
      summary: 'Speak',
      args: const {'text': 'Hello'},
      result: jsonEncode({'success': true, 'file_path': '/srv/voice.ogg'}),
    );
    expect(voiceTranscript(audio, [call]), 'Hello');
    expect(
      voiceTranscript(audio, [
        tts(
          data: {
            'success': true,
            'media_tag': '[[audio_as_voice]]\nMEDIA:/srv/voice.ogg',
          },
        ),
      ]),
      isNotNull,
    );
  });

  test(
    'does not claim the complete input is a transcript of one split part',
    () {
      expect(
        voiceTranscript(audio, [
          tts(
            data: {
              'success': true,
              'file_paths': ['/srv/voice.ogg', '/srv/part2.ogg'],
              'file_path': '/srv/voice.ogg',
            },
          ),
        ]),
        isNull,
      );
      expect(
        voiceTranscript(audio, [
          tts(
            data: {
              'success': true,
              'file_path': '/srv/voice.ogg',
              'delivery_file_count': 2,
            },
          ),
        ]),
        isNull,
      );
      expect(
        voiceTranscript(audio, [
          tts(
            data: {
              'success': true,
              'file_path': '/srv/voice.ogg',
              'combined_chunks': true,
              'delivery_file_count': 1,
            },
          ),
        ]),
        isNotNull,
      );
    },
  );

  test(
    'restores a transcript from separate stored tool and assistant rows',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions/s1/messages',
          messageListBody('s1', [
            messageRow(
              id: 1,
              role: 'user',
              content: 'Send me a voice briefing',
            ),
            messageRow(
              id: 2,
              role: 'assistant',
              content: '',
              toolCalls: [
                {
                  'id': 'tts1',
                  'type': 'function',
                  'function': {
                    'name': 'text_to_speech',
                    'arguments': jsonEncode({
                      'text': 'Your briefing is ready.',
                    }),
                  },
                },
              ],
            ),
            messageRow(
              id: 3,
              role: 'tool',
              toolCallId: 'tts1',
              content: jsonEncode({
                'success': true,
                'file_path': '/srv/voice.ogg',
              }),
            ),
            messageRow(
              id: 4,
              role: 'assistant',
              content: '[[audio_as_voice]]\nMEDIA:/srv/voice.ogg',
            ),
            messageRow(id: 5, role: 'user', content: 'Next question'),
            messageRow(
              id: 6,
              role: 'assistant',
              content: 'MEDIA:/srv/voice.ogg',
            ),
          ]),
        );
      final messages = await HermesChatRepository(server.client().raw)
          .loadMessages('s1');
      final files = chatMessagesToFlyer(messages)
          .whereType<FileMessage>()
          .toList();
      expect(files, hasLength(2));
      expect(
        files.first.metadata![kMetaVoiceTranscript],
        'Your briefing is ready.',
      );
      expect(files.last.metadata![kMetaVoiceTranscript], isNull);
    },
  );

  test('attaches the transcript to a live reply with its own tool calls', () {
    final reply = ChatMessage(
      id: 'r',
      role: ChatRole.assistant,
      content: 'MEDIA:/srv/voice.ogg',
      createdAt: DateTime.utc(2026),
      toolCalls: [tts()],
    );
    final file = chatMessageToFlyer(reply).whereType<FileMessage>().single;
    expect(
      file.metadata![kMetaVoiceTranscript],
      'Here is your morning briefing.',
    );
  });
}
