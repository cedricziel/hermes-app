import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

void main() {
  const scope = WatchContext('context', 1);
  const events = <String, ChatEvent>{
    'approval': ApprovalRequested(
      ApprovalRequest(
        requestId: 'r',
        command: 'echo demo',
        description: '',
        choices: ['once', 'deny'],
      ),
    ),
    'question': ClarifyRequested(
      ClarifyRequest(
        requestId: 'r',
        questions: [ClarifyQuestion(qid: 'q', question: 'Continue?')],
      ),
    ),
  };
  for (final entry in events.entries) {
    for (final eligible in [true, false]) {
      test(
        '${entry.key} without notifications waits only for exact eligible inline request $eligible',
        () async {
          final server = FakeHermesServer();
          final transport = FakeChatTransport();
          final handler = WatchRequestHandler(
            context: () => scope,
            repository: () => HermesChatRepository(server.client().raw),
            transport: () => transport,
            activeProfile: () async => 'work',
            announce: (_) async => false,
            requestsAllowed: () => true,
            requestEligible: (owner, profile, thread, id, kind) =>
                eligible &&
                owner.id == scope.id &&
                owner.revision == scope.revision &&
                profile == 'work' &&
                thread == 'thread' &&
                id == 'r' &&
                kind == entry.key,
          );
          final pending = handler.handle({
            'op': 'send',
            ...scope.fields,
            'sendId': 'send',
            'text': 'Hello',
            'waits': true,
          });
          await pumpEventQueue();
          transport.sends.single
            ..emit(const ThreadBound('thread'))
            ..emit(entry.value);
          final result = await pending;
          if (eligible) {
            expect(result['waiting'], entry.key);
            expect(result['inlineEligible'], isTrue);
            transport.sends.single.emit(const ReplyCompleted('Done'));
            await pumpEventQueue();
          } else {
            expect(result['waiting'], isNull);
            expect(result['text'], contains("watch can't answer"));
          }
          handler.invalidateSession();
        },
      );
    }
  }
}
