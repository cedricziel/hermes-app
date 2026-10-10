import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/request_notifications.dart';

ApprovalRequest _approval(List<String> choices) => ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: choices,
);

ClarifyRequest _question(
  List<String> choices, {
  bool multiSelect = false,
  String qid = 'q1',
}) => ClarifyRequest(
  requestId: 'r2',
  batch: true,
  questions: [
    ClarifyQuestion(
      qid: qid,
      question: 'Which branch?',
      choices: choices,
      multiSelect: multiSelect,
    ),
  ],
);

List<String> _ids(RequestCategory? category) => [
  for (final action in category!.actions) action.id,
];

List<String> _titles(RequestCategory? category) => [
  for (final action in category!.actions) action.title,
];

void main() {
  group('approval categories', () {
    test('offer every choice the agent gave, in a fixed order', () {
      final category = requestCategoryFor(
        _approval(['deny', 'always', 'session', 'once']),
      );

      expect(category!.id, 'hermes.request.approval.once-session-always-deny');
      expect(_titles(category), [
        'Allow once',
        'Allow for session',
        'Always allow',
        'Deny',
      ]);
      expect(_ids(category), [
        kAllowOnceAction,
        kAllowSessionAction,
        kAllowAlwaysAction,
        kDenyAction,
      ]);
      expect(category.placeholder, kApprovalBody);
    });

    test('offer only the choices the agent gave', () {
      final category = requestCategoryFor(_approval(['once', 'deny']));

      expect(category!.id, 'hermes.request.approval.once-deny');
      expect(_titles(category), ['Allow once', 'Deny']);
    });

    test('mark Always and Deny destructive and nothing else', () {
      final category = requestCategoryFor(
        _approval(['once', 'session', 'always', 'deny']),
      );

      expect(
        [
          for (final action in category!.actions)
            if (action.destructive) action.id,
        ],
        [kAllowAlwaysAction, kDenyAction],
      );
    });

    test('run in the background', () {
      final category = requestCategoryFor(
        _approval(['once', 'session', 'always', 'deny']),
      );

      expect(category!.actions.any((action) => action.foreground), isFalse);
    });

    test(
      'show only the placeholder for an approval without a known choice',
      () {
        final category = requestCategoryFor(_approval(['later']))!;

        expect(category.id, kApprovalPlaceholderCategory);
        expect(category.actions, isEmpty);
        expect(category.placeholder, kApprovalBody);
        expect(pendingRequestFor(_approval(['later'])), isNull);
      },
    );

    test('show only the placeholder while App Lock is on', () {
      final category = requestCategoryFor(
        _approval(['once', 'deny']),
        appLock: true,
      )!;

      expect(category.id, kApprovalPlaceholderCategory);
      expect(category.actions, isEmpty);
    });

    test('exist for every combination at start', () {
      final ids = {for (final c in staticRequestCategories()) c.id};

      expect(ids, contains('hermes.request.approval.once-session-always-deny'));
      expect(ids, contains('hermes.request.approval.deny'));
      expect(ids, contains(kQuestionCategory));
      expect(ids, contains(kApprovalPlaceholderCategory));
      expect(ids, contains(kQuestionPlaceholderCategory));
      expect(
        ids.where((id) => id.startsWith('$kApprovalCategoryPrefix.')).length,
        15,
      );
      for (final choices in [
        ['once', 'deny'],
        ['session', 'always'],
        ['once', 'session', 'always', 'deny'],
      ]) {
        expect(ids, contains(requestCategoryFor(_approval(choices))!.id));
      }
    });
  });

  group('question categories', () {
    test('offer each of up to four choices and Reply', () {
      final category = requestCategoryFor(
        _question(['main', 'dev', 'release', 'hotfix']),
      );

      expect(_titles(category), ['main', 'dev', 'release', 'hotfix', 'Reply']);
      expect(_ids(category), [
        '${kChoiceActionPrefix}0',
        '${kChoiceActionPrefix}1',
        '${kChoiceActionPrefix}2',
        '${kChoiceActionPrefix}3',
        kReplyAction,
      ]);
      expect(category!.placeholder, kQuestionBody);
      expect(category.id, startsWith('$kQuestionCategory.'));
    });

    test('offer three choices and Other… above four', () {
      final category = requestCategoryFor(_question(['a', 'b', 'c', 'd', 'e']));

      expect(_titles(category), ['a', 'b', 'c', 'Other…', 'Reply']);
      final other = category!.actions[3];
      expect(other.id, kOpenAction);
      expect(other.foreground, isTrue);
    });

    test('are named after their buttons', () {
      expect(
        requestCategoryFor(_question(['a', 'b']))!.id,
        requestCategoryFor(_question(['a', 'b']))!.id,
      );
      expect(
        requestCategoryFor(_question(['a', 'b']))!.id,
        isNot(requestCategoryFor(_question(['a', 'c']))!.id),
      );
      expect(
        requestCategoryFor(_question(['a', 'b', 'c']))!.id,
        isNot(requestCategoryFor(_question(['a', 'b', 'c', 'd', 'e']))!.id),
        reason: 'only one of them has Other…',
      );
    });

    test('offer only Reply and Open for a multi-select question', () {
      final category = requestCategoryFor(
        _question(['a', 'b'], multiSelect: true),
      );

      expect(category!.id, kQuestionCategory);
      expect(_ids(category), [kReplyAction, kOpenAction]);
    });

    test('offer Reply and Open for an open-ended question', () {
      final category = requestCategoryFor(_question(const []));

      expect(category!.id, kQuestionCategory);
      final reply = category.actions.first;
      expect(reply.textInput, isTrue);
      expect(category.actions.last.foreground, isTrue);
    });

    test('show only the placeholder while App Lock is on', () {
      final category = requestCategoryFor(_question(['a']), appLock: true)!;

      expect(category.id, kQuestionPlaceholderCategory);
      expect(category.actions, isEmpty);
      expect(category.placeholder, kQuestionBody);
    });

    test('show only the placeholder for a request with several questions', () {
      const batch = ClarifyRequest(
        requestId: 'r2',
        batch: true,
        questions: [
          ClarifyQuestion(qid: 'a', question: 'One?'),
          ClarifyQuestion(qid: 'b', question: 'Two?'),
        ],
      );

      expect(requestCategoryFor(batch)!.id, kQuestionPlaceholderCategory);
      expect(pendingRequestFor(batch), isNull);
    });
  });

  test('requests the app cannot answer get no category', () {
    expect(
      requestCategoryFor(
        const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.sudo),
      ),
      isNull,
    );
    expect(
      requestCategoryFor(
        const VaultRequest(requestId: 'r', kind: VaultKind.code),
      ),
      isNull,
    );
  });

  test('every action needs the device unlocked', () {
    for (final category in [
      ...staticRequestCategories(),
      requestCategoryFor(_question(['a', 'b', 'c', 'd', 'e']))!,
    ]) {
      for (final action in category.toDarwin().actions) {
        expect(
          action.options,
          contains(DarwinNotificationActionOption.authenticationRequired),
          reason: '${category.id} ${action.identifier}',
        );
      }
    }
  });

  test('the Reply action is a text input', () {
    final reply = requestCategoryFor(_question(['a']))!.toDarwin().actions.last;

    expect(reply.identifier, kReplyAction);
    expect(reply.placeholder, 'Your answer');
    expect(reply.buttonTitle, 'Send');
  });

  group('pending requests', () {
    test('of an approval remember its id', () {
      final pending = pendingRequestFor(_approval(['once', 'deny']))!;

      expect(pending.requestId, 'r1');
      expect(pending.kind, PendingRequestKind.approval);
    });

    test('of a question remember the buttons it shows', () {
      final pending = pendingRequestFor(_question(['a', 'b', 'c', 'd', 'e']))!;

      expect(pending.kind, PendingRequestKind.question);
      expect(pending.questionId, 'q1');
      expect(pending.choices, ['a', 'b', 'c']);
    });

    test('survive the payload', () {
      final pending = pendingRequestFor(
        _question(['a', 'b'], multiSelect: true),
      )!;

      final decoded = PendingRequest.fromJson(pending.toJson())!;

      expect(decoded.requestId, 'r2');
      expect(decoded.kind, PendingRequestKind.question);
      expect(decoded.questionId, 'q1');
      expect(decoded.multiSelect, isTrue);
      expect(decoded.choices, isEmpty);
      expect(
        PendingRequest.fromJson(
          pendingRequestFor(_question(['a', 'b']))!.toJson(),
        )!.choices,
        ['a', 'b'],
      );
    });

    test('remember a request raised as an event', () {
      final pending = pendingRequestFor(
        _approval(['once']),
        raisedAsEvent: true,
      )!;

      expect(PendingRequest.fromJson(pending.toJson())!.raisedAsEvent, isTrue);
      expect(
        PendingRequest.fromJson(
          pendingRequestFor(_approval(['once']))!.toJson(),
        )!.raisedAsEvent,
        isFalse,
      );
    });

    test('reject a payload that is not one', () {
      expect(PendingRequest.fromJson('nope'), isNull);
      expect(PendingRequest.fromJson({'k': 'approval'}), isNull);
      expect(PendingRequest.fromJson({'i': 'r', 'k': 'sudo'}), isNull);
    });
  });

  group('answers', () {
    final approval = pendingRequestFor(
      _approval(['once', 'session', 'always', 'deny']),
    )!;
    final question = pendingRequestFor(_question(['main', 'dev']))!;

    test('of an approval are its choice', () {
      for (final (action, choice) in [
        (kAllowOnceAction, 'once'),
        (kAllowSessionAction, 'session'),
        (kAllowAlwaysAction, 'always'),
        (kDenyAction, 'deny'),
      ]) {
        final answer = answerFor(approval, action, null);
        expect(answer, isA<ApprovalChoiceAnswer>());
        expect((answer! as ApprovalChoiceAnswer).choice, choice);
      }
    });

    test('of a choice button are its title', () {
      final answer =
          answerFor(question, '${kChoiceActionPrefix}1', null)!
              as QuestionAnswer;

      expect(answer.questionId, 'q1');
      expect(answer.values, ['dev']);
      expect(answer.multiSelect, isFalse);
    });

    test('of Reply are the typed text', () {
      final answer =
          answerFor(question, kReplyAction, '  the second one ')!
              as QuestionAnswer;

      expect(answer.values, ['the second one']);
    });

    test('of Reply to a multi-select question keep it multi-select', () {
      final multi = pendingRequestFor(
        _question(['a', 'b'], multiSelect: true),
      )!;

      final answer =
          answerFor(multi, kReplyAction, 'a and b')! as QuestionAnswer;

      expect(answer.multiSelect, isTrue);
      expect(answer.values, ['a and b']);
    });

    test('are none for an empty reply, Other…, Open or a stray action', () {
      expect(answerFor(question, kReplyAction, '  '), isNull);
      expect(answerFor(question, kOpenAction, null), isNull);
      expect(answerFor(question, kOpenAction, null), isNull);
      expect(answerFor(question, '${kChoiceActionPrefix}7', null), isNull);
      expect(answerFor(approval, '${kChoiceActionPrefix}0', null), isNull);
      expect(answerFor(question, kAllowOnceAction, null), isNull);
    });
  });
}
