import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';

ChatThread _thread([String id = 't1']) =>
    ChatThread(id: id, title: 'Release notes', updatedAt: DateTime(2026));

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

const _question = ClarifyRequest(
  requestId: 'r2',
  questions: [ClarifyQuestion(qid: '', question: 'Which colour?')],
);

AttentionNotification? _for(
  ChatEvent event, {
  bool focused = false,
  String? selected,
  bool enabled = true,
}) => attentionFor(
  event: event,
  thread: _thread(),
  appFocused: focused,
  selectedThreadId: selected,
  enabled: enabled,
);

void main() {
  group('replyPreview', () {
    test('keeps a short reply as it is', () {
      expect(replyPreview('Done.'), 'Done.');
    });

    test('collapses whitespace and newlines', () {
      expect(replyPreview('  a\n\n  b\tc '), 'a b c');
    });

    test('cuts a long reply at 120 characters with an ellipsis', () {
      expect(replyPreview('x' * 200), '${'x' * 120}…');
    });

    test('does not add an ellipsis at exactly 120 characters', () {
      expect(replyPreview('x' * 120), 'x' * 120);
    });
  });

  group('what is said', () {
    test('a finished reply carries its preview under the thread title', () {
      final n = _for(const ReplyCompleted('Done.'))!;

      expect(n.threadId, 't1');
      expect(n.title, 'Release notes');
      expect(n.body, 'Done.');
    });

    test('an empty reply says it is ready', () {
      expect(_for(const ReplyCompleted(''))!.body, kReplyReadyBody);
    });

    test('a failed reply says so, not its error text', () {
      final n = _for(const ReplyCompleted('boom: trace', failed: true))!;

      expect(n.body, 'Reply failed');
    });

    test('an approval never shows the command', () {
      final n = _for(const ApprovalRequested(_approval))!;

      expect(n.body, 'Waiting for your approval');
      expect(n.body, isNot(contains('rm')));
    });

    test('a clarify question never shows the question', () {
      final n = _for(const ClarifyRequested(_question))!;

      expect(n.body, 'Has a question for you');
    });
  });

  group('when it is said', () {
    const events = <ChatEvent>[
      ReplyCompleted('Done.'),
      ApprovalRequested(_approval),
      ClarifyRequested(_question),
    ];

    test('never while the app is focused on that thread', () {
      for (final event in events) {
        expect(_for(event, focused: true, selected: 't1'), isNull);
      }
    });

    test('when the app is focused on another thread', () {
      for (final event in events) {
        expect(_for(event, focused: true, selected: 't2'), isNotNull);
      }
    });

    test('when the app is focused and no thread is selected', () {
      expect(_for(events.first, focused: true, selected: null), isNotNull);
    });

    test('when the app is not focused, even on the selected thread', () {
      for (final event in events) {
        expect(_for(event, focused: false, selected: 't1'), isNotNull);
      }
    });

    test('never when notifications are off', () {
      for (final event in events) {
        expect(_for(event, enabled: false), isNull);
      }
    });

    test('not for events that are not worth an alert', () {
      const quiet = <ChatEvent>[
        ReplyStarted(),
        ReplyDelta('x'),
        ToolStarted(name: 'shell'),
        ToolFinished(name: 'shell'),
        ThreadTitled('New title'),
        ThreadBound('t9'),
        InputRequestExpired('r1'),
      ];
      for (final event in quiet) {
        expect(_for(event), isNull);
      }
    });
  });
}
