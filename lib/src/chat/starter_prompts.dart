import 'package:characters/characters.dart';

/// Where a starter prompt came from; it picks the card's icon.
enum StarterSource { generic, schedule, kanban, chat, skill }

/// What tapping a starter prompt does.
enum StarterAction { send, prefill, openThread }

class StarterPrompt {
  const StarterPrompt(
    this.text, {
    this.source = StarterSource.generic,
    this.action = StarterAction.send,
    this.threadId,
  });

  final String text;
  final StarterSource source;
  final StarterAction action;

  /// The chat to open, for [StarterAction.openThread].
  final String? threadId;
}

class StarterTask {
  const StarterTask(this.title, {required this.blocked});

  final String title;

  /// False for a task waiting for review.
  final bool blocked;
}

class StarterChat {
  const StarterChat({required this.id, required this.title});

  final String id;
  final String title;
}

/// One item per source, each null when the source has nothing to offer.
class StarterContext {
  const StarterContext({
    this.failedJob,
    this.kanbanTask,
    this.recentChat,
    this.skill,
  });

  final String? failedJob;
  final StarterTask? kanbanTask;
  final StarterChat? recentChat;
  final String? skill;
}

/// Starter prompts that fit any server, used where the user's context has
/// none to offer.
const List<String> kStarterPrompts = [
  'What can you help me with?',
  'Which skills and tools can you use?',
  'Draft a status update for the team',
  'Help me think through a problem',
];

/// The generic prompts, for a welcome view shown before any context.
final List<StarterPrompt> kGenericStarterPrompts = List.unmodifiable(
  buildStarterPrompts(const StarterContext()),
);

const int _maxNameLength = 60;
const int _starterPromptCount = 4;

String _cut(String name) {
  final characters = name.characters;
  return characters.length <= _maxNameLength
      ? name
      : '${characters.take(_maxNameLength - 1)}…';
}

/// The welcome view's prompts: one per source that has something, in a fixed
/// order, then generic ones up to four.
List<StarterPrompt> buildStarterPrompts(StarterContext context) {
  final prompts = <StarterPrompt>[
    if (context.failedJob case final job?)
      StarterPrompt(
        "Why did the scheduled job '${_cut(job)}' fail on its last run?",
        source: StarterSource.schedule,
        action: StarterAction.prefill,
      ),
    if (context.kanbanTask case final task?)
      StarterPrompt(
        task.blocked
            ? "What's blocking the Kanban task '${_cut(task.title)}'?"
            : "What's left before the Kanban task '${_cut(task.title)}' is "
                  'done?',
        source: StarterSource.kanban,
        action: StarterAction.prefill,
      ),
    if (context.recentChat case final chat?)
      StarterPrompt(
        "Pick up '${_cut(chat.title)}'",
        source: StarterSource.chat,
        action: StarterAction.openThread,
        threadId: chat.id,
      ),
    if (context.skill case final skill?)
      StarterPrompt(
        'Use the ${_cut(skill)} skill to ',
        source: StarterSource.skill,
        action: StarterAction.prefill,
      ),
  ];
  return [
    ...prompts,
    for (final text in kStarterPrompts.take(
      _starterPromptCount - prompts.length,
    ))
      StarterPrompt(text),
  ];
}
