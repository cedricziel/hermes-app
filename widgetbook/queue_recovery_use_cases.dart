import 'package:hermes_app/src/chat/queued_prompt.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/chat/widgets/queued_prompts.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode queueRecoveryNode() => WidgetbookComponent(
  name: 'Queue recovery',
  useCases: [
    for (final expanded in [false, true])
      WidgetbookUseCase(
        name: expanded ? 'Ordinary queue, expanded' : 'Ordinary queue, compact',
        builder: (_) => frame(
          QueuedPrompts(
            prompts: const [
              QueuedPrompt('Done!', []),
              QueuedPrompt('Then summarize the results', []),
            ],
            initiallyExpanded: expanded,
            onRemove: (_) {},
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'Long ordinary queue',
      builder: (_) => frame(
        QueuedPrompts(
          prompts: [
            for (var i = 0; i < 30; i++)
              QueuedPrompt('Follow-up message ${i + 1}', []),
          ],
          onRemove: (_) {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Recovered FIFO',
      builder: (_) => frame(
        QueuedPrompts(
          prompts: const [
            QueuedPrompt('Review the release checklist', []),
            QueuedPrompt('Summarize the test results', []),
          ],
          reviewRequired: true,
          onRemove: (_) {},
          onSendNow: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Unknown submission',
      builder: (_) => frame(
        QueuedPrompts(
          prompts: const [
            QueuedPrompt(
              'Check the build',
              [],
              durable: QueueRecord(
                id: 'entry',
                sequence: 0,
                text: 'Check the build',
                state: QueueRecordState.submissionStarted,
              ),
            ),
          ],
          reviewRequired: true,
          onRemove: (_) {},
          onSendNow: () {},
          onInspect: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Unavailable session',
      builder: (_) => frame(
        QueuedPrompts(
          prompts: const [QueuedPrompt('Held for its original session', [])],
          reviewRequired: true,
          available: false,
          onRemove: (_) {},
          onSendNow: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Missing attachment',
      builder: (_) => frame(
        QueuedPrompts(
          prompts: const [QueuedPrompt('Read this attachment', [])],
          reviewRequired: true,
          storageError:
              'Could not read the retained attachment. Nothing was sent.',
          onRemove: (_) {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Persistence failure',
      builder: (_) => frame(
        QueuedPrompts(
          prompts: const [QueuedPrompt('Previously retained prompt', [])],
          reviewRequired: true,
          storageError:
              'Protected storage is unavailable. Your draft was kept.',
          onRemove: (_) {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'App Lock',
      builder: (_) => frame(
        QueuedPrompts(
          prompts: const [QueuedPrompt('Private recovered text', [])],
          reviewRequired: true,
          locked: true,
          onRemove: (_) {},
          onSendNow: () {},
        ),
      ),
    ),
  ],
);
