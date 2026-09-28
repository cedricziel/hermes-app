import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/starter_prompts.dart';

void main() {
  test('an empty context gives the four generic prompts that send', () {
    final prompts = buildStarterPrompts(const StarterContext());

    expect(prompts.map((p) => p.text), kStarterPrompts);
    expect(prompts.map((p) => p.source), everyElement(StarterSource.generic));
    expect(prompts.map((p) => p.action), everyElement(StarterAction.send));
  });

  test('a full context gives one prompt per source, in order', () {
    final prompts = buildStarterPrompts(
      const StarterContext(
        failedJob: 'Nightly backup',
        kanbanTask: StarterTask('Migrate auth', blocked: true),
        recentChat: StarterChat(id: 't1', title: 'Telegram pairing'),
        skill: 'nextcloud-notes',
      ),
    );

    expect(prompts.map((p) => (p.text, p.source, p.action)), [
      (
        "Why did the scheduled job 'Nightly backup' fail on its last run?",
        StarterSource.schedule,
        StarterAction.prefill,
      ),
      (
        "What's blocking the Kanban task 'Migrate auth'?",
        StarterSource.kanban,
        StarterAction.prefill,
      ),
      (
        "Pick up 'Telegram pairing'",
        StarterSource.chat,
        StarterAction.openThread,
      ),
      (
        'Use the nextcloud-notes skill to ',
        StarterSource.skill,
        StarterAction.prefill,
      ),
    ]);
    expect(prompts[2].threadId, 't1');
  });

  test('a partial context goes first and generic prompts fill the rest', () {
    final prompts = buildStarterPrompts(
      const StarterContext(
        recentChat: StarterChat(id: 't1', title: 'Telegram pairing'),
      ),
    );

    expect(prompts.map((p) => p.text), [
      "Pick up 'Telegram pairing'",
      ...kStarterPrompts.take(3),
    ]);
  });

  test('a task waiting for review asks what is left', () {
    final prompts = buildStarterPrompts(
      const StarterContext(
        kanbanTask: StarterTask('Migrate auth', blocked: false),
      ),
    );

    expect(
      prompts.first.text,
      "What's left before the Kanban task 'Migrate auth' is done?",
    );
  });

  test('a long name is cut between characters, not inside an emoji', () {
    final name = '${'x' * 58}🙂🙂 and more';
    final prompts = buildStarterPrompts(StarterContext(failedJob: name));

    expect(
      prompts.first.text,
      "Why did the scheduled job '${'x' * 58}🙂…' fail on its last run?",
    );
  });

  test('a long name is cut to 60 characters', () {
    final name = 'x' * 80;
    final prompts = buildStarterPrompts(StarterContext(failedJob: name));

    expect(
      prompts.first.text,
      "Why did the scheduled job '${'x' * 59}…' fail on its last run?",
    );
  });
}
