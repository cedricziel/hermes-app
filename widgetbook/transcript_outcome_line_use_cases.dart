import 'package:flutter/widgets.dart';
import 'package:hermes_app/src/chat/widgets/transcript_outcome_line.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookUseCase _case(String name, String text) => WidgetbookUseCase(
  name: name,
  builder: (_) => frame(TranscriptOutcomeLine(text: text), maxWidth: 560),
);

WidgetbookFolder transcriptOutcomeLineNode() => WidgetbookFolder(
  name: 'TranscriptOutcomeLine',
  children: [
    WidgetbookComponent(
      name: 'TranscriptOutcomeLine',
      useCases: [
        _case('Compressed', 'Conversation compressed · 42 → 9 messages'),
        _case(
          'Restored, last message removed',
          'Restored 3 files · removed your last message',
        ),
        _case(
          'Files restored, count unknown, last message removed',
          'Files restored · removed your last message',
        ),
        _case('Restored 1 file', 'Restored 1 file'),
        WidgetbookUseCase(
          name: 'Largest text, no hairlines',
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: frame(
              const TranscriptOutcomeLine(
                text: 'Conversation compressed · 42 → 9 messages',
              ),
              maxWidth: 360,
            ),
          ),
        ),
        _case(
          'Long sentence wraps',
          'Conversation compressed · 4,210 → 912 messages · Hermes could not '
              'summarize the older messages, so it dropped them',
        ),
      ],
    ),
  ],
);
