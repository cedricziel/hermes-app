import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_notification_service.dart';

/// A reply that replaced an earlier one after Retry or Edit is marked. Hermes
/// stores no such flag, so the mark lives in this session's messages only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late AttentionNotifier attention;
  late ChatController chat;
  late ChatThread thread;
  late ValueNotifier<bool> activity;
  String? prefilled;

  setUp(() {
    transport = FakeChatTransport();
    attention = AttentionNotifier(
      service: FakeNotificationService(),
      settings: null,
      onOpen: (_) {},
    );
    activity = ValueNotifier(true);
    chat = ChatController(
      activity: activity,
      transport: transport,
      attention: attention,
      report: (_) {},
      onPrefill: (text) => prefilled = text,
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  /// A first prompt that got its reply.
  Future<void> firstTurn() async {
    chat.newThread();
    thread = chat.selectedThread!;
    await chat.submit('Plan it', const []);
    transport.sends.last
      ..emit(const ThreadBound('s1'))
      ..emit(const ReplyDelta('First answer'))
      ..emit(const ReplyCompleted('First answer'))
      ..finish();
    await pumpEventQueue();
  }

  Future<void> answerLast(String text) async {
    transport.sends.last
      ..emit(ReplyDelta(text))
      ..emit(ReplyCompleted(text))
      ..finish();
    await pumpEventQueue();
  }

  List<ChatMessage> replies() => [
    for (final m in thread.messages)
      if (m.role == ChatRole.assistant) m,
  ];

  /// The metadata the chat list reads off the last reply's text.
  Map<String, dynamic>? lastReplyMeta() => chat
      .controllerFor(thread)
      .messages
      .whereType<TextMessage>()
      .lastWhere((m) => m.authorId != 'user')
      .metadata;

  test('a reply to a prompt that was not retried carries no marker', () async {
    await firstTurn();

    expect(replies().single.regenerated, isFalse);
    expect(lastReplyMeta()?[kMetaRegenerated], isNull);
  });

  test('Retry marks the reply that replaces the dropped one', () async {
    await firstTurn();

    await chat.retry(thread);
    await answerLast('Second answer');

    expect(transport.undos, [('s1', true)]);
    expect(replies().single.content, 'Second answer');
    expect(replies().single.regenerated, isTrue);
    expect(lastReplyMeta()?[kMetaRegenerated], isTrue);
  });

  test('Edit marks the reply to the prompt sent in its place', () async {
    await firstTurn();

    await chat.editLastPrompt(thread);
    expect(prefilled, 'Plan it');
    await chat.submit('Plan it better', const []);
    await answerLast('Better answer');

    expect(transport.undos, [('s1', false)]);
    expect(replies().single.regenerated, isTrue);
    expect(lastReplyMeta()?[kMetaRegenerated], isTrue);
  });

  test('the mark covers one reply: the next prompt gets a plain one', () async {
    await firstTurn();
    await chat.retry(thread);
    await answerLast('Second answer');

    await chat.submit('And then?', const []);
    await answerLast('Third answer');

    expect([for (final m in replies()) m.regenerated], [true, false]);
    expect(lastReplyMeta()?[kMetaRegenerated], isNull);
  });

  test('a retry the server refuses marks nothing', () async {
    await firstTurn();
    transport.undoRemoved = null;

    await chat.retry(thread);
    await answerLast('Another answer');

    expect([for (final m in replies()) m.regenerated], [false, false]);
  });

  test('a Retry that went stale during its undo marks nothing', () async {
    await firstTurn();
    transport.undoGate = Completer<void>();

    final retry = chat.retry(thread);
    activity.value = false;
    activity.value = true;
    await pumpEventQueue();
    transport.undoGate!.complete();
    await retry;
    await pumpEventQueue();
    await chat.submit('Something else', const []);
    await answerLast('Unrelated answer');

    expect([for (final m in replies()) m.regenerated], everyElement(isFalse));
  });

  test('a turn another client starts after an Edit is not marked', () async {
    await firstTurn();
    await chat.editLastPrompt(thread);

    transport.followUpStreams['s1']!
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('From elsewhere'))
      ..emit(const ReplyCompleted('From elsewhere'));
    await pumpEventQueue();

    expect(replies().single.content, 'From elsewhere');
    expect(replies().single.regenerated, isFalse);
  });

  test('a pending Edit mark does not survive the activity going off', () async {
    await firstTurn();
    await chat.editLastPrompt(thread);

    activity.value = false;
    activity.value = true;
    await pumpEventQueue();
    await chat.submit('Something else', const []);
    await answerLast('Unrelated answer');

    expect(replies().single.regenerated, isFalse);
  });

  test(
    'a pending Edit mark does not survive reopening a reclaimed session',
    () async {
      await firstTurn();
      await chat.editLastPrompt(thread);

      transport.followUpStreams['s1']!.emit(
        const SessionReclaimed('runtime-a', 's1', 'Another client took over'),
      );
      await pumpEventQueue();
      chat.reopenSession(thread);
      await chat.submit('Something else', const []);
      await answerLast('Unrelated answer');

      expect(replies().single.regenerated, isFalse);
    },
  );

  test('a regenerated reply that fails carries no marker', () async {
    await firstTurn();
    await chat.retry(thread);

    transport.sends.last
      ..emit(const ReplyDelta('Half an answer'))
      ..fail(StateError('boom'));
    await pumpEventQueue();

    expect(replies().single.status, MessageStatus.error);
    expect(lastReplyMeta()?[kMetaRegenerated], isNull);
  });

  test('a Retry whose prompt Hermes took as a stop phrase hands the mark to '
      'the next reply', () async {
    await firstTurn();
    await chat.retry(thread);
    transport.sends.last.emit(
      const PromptAccepted(PromptAccepted.voiceStopped),
    );
    await pumpEventQueue();
    expect(replies(), isEmpty);

    await chat.submit('Plan it differently', const []);
    await answerLast('Second answer');

    expect(replies().single.regenerated, isTrue);
  });
}
