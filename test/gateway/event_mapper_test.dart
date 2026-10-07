import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

ChatEvent? map(String type, [Map<String, Object?> payload = const {}]) =>
    mapGatewayEvent(GatewayEvent(type: type, sessionId: 's', payload: payload));

void main() {
  group('message.complete flags (3.1)', () {
    test('a complete reply with response_previewed maps to previewed', () {
      final event = map('message.complete', {
        'text': 'hi',
        'status': 'complete',
        'response_previewed': true,
      }) as ReplyCompleted;

      expect(event.previewed, isTrue);
      expect(event.reused, isFalse);
      expect(event.transformed, isFalse);
      expect(event.failed, isFalse);
    });

    test('response_reused and response_transformed map to reused and '
        'transformed', () {
      final reused = map('message.complete', {
        'text': 'hi',
        'status': 'complete',
        'response_reused': true,
      }) as ReplyCompleted;
      final transformed = map('message.complete', {
        'text': 'hi',
        'status': 'complete',
        'response_transformed': true,
      }) as ReplyCompleted;

      expect(reused.reused, isTrue);
      expect(reused.previewed, isFalse);
      expect(transformed.transformed, isTrue);
      expect(transformed.reused, isFalse);
    });

    test('a failed partial reply keeps its text, error and partial flag', () {
      final event = map('message.complete', {
        'status': 'error',
        'partial': true,
        'error': 'boom',
        'text': 'ans',
      }) as ReplyCompleted;

      expect(event.failed, isTrue);
      expect(event.partial, isTrue);
      expect(event.error, 'boom');
      expect(event.text, 'ans');
    });

    test('missing or non-bool completion flags read as false', () {
      final missing = map('message.complete', {
        'text': 'x',
        'status': 'complete',
      }) as ReplyCompleted;
      final nonBool = map('message.complete', {
        'text': 'x',
        'status': 'complete',
        'response_previewed': 'yes',
        'response_reused': 1,
        'response_transformed': 'true',
        'partial': 'true',
      }) as ReplyCompleted;

      expect(missing.previewed, isFalse);
      expect(missing.reused, isFalse);
      expect(missing.transformed, isFalse);
      expect(missing.partial, isFalse);
      expect(missing.error, isNull);
      expect(nonBool.previewed, isFalse);
      expect(nonBool.reused, isFalse);
      expect(nonBool.transformed, isFalse);
      expect(nonBool.partial, isFalse);
    });
  });

  group('message.interim (3.2)', () {
    test('interim with already_streamed false is an unstreamed checkpoint', () {
      final event = map('message.interim', {
        'text': 'X',
        'already_streamed': false,
      }) as ReplyCheckpoint;

      expect(event.text, 'X');
      expect(event.alreadyStreamed, isFalse);
    });

    test('interim without already_streamed is a streamed checkpoint', () {
      final event = map('message.interim', {'text': 'X'}) as ReplyCheckpoint;

      expect(event.alreadyStreamed, isTrue);
    });
  });

  group('error and session.info (3.3)', () {
    test('error event maps to ReplyErrored with its message', () {
      final event = map('error', {'message': 'm'}) as ReplyErrored;

      expect(event.message, 'm');
    });

    test('session.info with running false maps to a settle signal with the '
        'stored id', () {
      final event = map('session.info', {
        'running': false,
        'stored_session_id': 'st2',
      }) as SessionInfo;

      expect(event.running, isFalse);
      expect(event.storedSessionId, 'st2');
    });

    test(
      'session.info with running true keeps the rotated stored id mid-turn',
      () {
        final event = map('session.info', {
          'running': true,
          'stored_session_id': 'st2',
        }) as SessionInfo;

        expect(event.running, isTrue);
        expect(event.storedSessionId, 'st2');
      },
    );

    test(
      'session.info with running true and no stored id has no stored id',
      () {
        final event = map('session.info', {'running': true}) as SessionInfo;

        expect(event.running, isTrue);
        expect(event.storedSessionId, isNull);
      },
    );

    test('an empty session.info says nothing about running', () {
      final event = map('session.info', {}) as SessionInfo;

      expect(event.running, isNull);
      expect(event.storedSessionId, isNull);
    });

    test('a non-bool running is read as unknown, keeping the stored id', () {
      final event = map('session.info', {
        'running': 'false',
        'stored_session_id': 'st3',
      }) as SessionInfo;

      expect(event.running, isNull);
      expect(event.storedSessionId, 'st3');
    });
  });

  group('status.update and thinking.delta (3.4)', () {
    test('a compacting status.update reads as the compacting status', () {
      final event = map('status.update', {
        'kind': 'compacting',
        'text': 'x',
      }) as ReplyStatus;

      expect(event.text, 'Compacting the conversation…');
    });

    test('other status.update kinds map to nothing', () {
      expect(map('status.update', {'kind': 'other', 'text': 'x'}), isNull);
    });

    test('an explained provider wait becomes the status text, trimmed', () {
      final event = map('thinking.delta', {
        'text': '  ⏳ waiting on local-model — 30s with no output yet  ',
      }) as ReplyStatus;

      expect(event.text, '⏳ waiting on local-model — 30s with no output yet');
    });

    test('spinner noise thinking.delta clears the status', () {
      final event =
          map('thinking.delta', {'text': '◉_◉ cogitating...'}) as ReplyStatus;

      expect(event.text, '');
    });

    test('an explained wait matches case-insensitively, e.g. rate limited', () {
      final event = map('thinking.delta', {
        'text': '↻ Rate Limited, retrying',
      }) as ReplyStatus;

      expect(event.text, '↻ Rate Limited, retrying');
    });
  });

  group('approval.cancelled (3.5)', () {
    test('approval.cancelled lists the withdrawn request ids', () {
      final event = map('approval.cancelled', {
        'session_id': 's',
        'request_ids': ['a', 'b'],
      }) as InputRequestsCancelled;

      expect(event.requestIds, ['a', 'b']);
    });

    test('approval.cancelled without request_ids withdraws every request', () {
      final event = map('approval.cancelled', {
        'session_id': 's',
      }) as InputRequestsCancelled;

      expect(event.requestIds, isEmpty);
    });
  });
}
