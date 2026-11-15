import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_reply.dart' show kReplyFailedMessage;
import 'package:hermes_app/src/chat/widgets/reply_error_note.dart';
import 'package:hermes_app/src/chat/widgets/reply_interrupted_note.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

/// The note under a reply the server no longer has, or could not be made to
/// say how it ended. It takes the sentence, so the locale addon shows German
/// too.
Widget _gone(BuildContext context) =>
    ReplyInterruptedNote(text: context.l10n.chatReplyInterruptedGone);

Widget _restarted(BuildContext context) =>
    ReplyInterruptedNote(text: context.l10n.chatReplyInterruptedRestarted);

Widget _unconfirmed(BuildContext context) => ReplyInterruptedNote(
  text: context.l10n.chatReplyUnconfirmed,
  unconfirmed: true,
);

WidgetbookUseCase _case(String name, WidgetBuilder builder, {double? width}) =>
    WidgetbookUseCase(
      name: name,
      builder: (context) => frame(builder(context), maxWidth: width ?? 480),
    );

/// A reply as the transcript draws it once it is settled: the text, its tool
/// calls (the one that was running is shown as not finished), then the note.
Widget _reply(Widget tail, {required Widget calls}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text('Starting the build. This takes a few minutes.'),
    const SizedBox(height: 8),
    calls,
    tail,
  ],
);

WidgetbookFolder replyInterruptedNode() => WidgetbookFolder(
  name: 'ReplyInterruptedNote',
  children: [
    WidgetbookComponent(
      name: 'ReplyInterruptedNote',
      useCases: [
        _case('Hermes restarted', _restarted),
        _case('No longer on the server', _gone),
        _case('Could not confirm', _unconfirmed),
        _case(
          'Restarted, under a reply whose call did not finish',
          (context) => _reply(
            _restarted(context),
            calls: const ToolCallGroup(calls: [cancelledToolCall]),
          ),
        ),
        _case(
          'No longer on the server, finished and unfinished calls',
          (context) => _reply(
            _gone(context),
            calls: ToolCallGroup(
              calls: [...finishedToolRun, cancelledToolCall],
            ),
          ),
        ),
        _case(
          'Could not confirm, under an unfinished call',
          (context) => _reply(
            _unconfirmed(context),
            calls: const ToolCallGroup(calls: [cancelledToolCall]),
          ),
        ),
        _case(
          'Beside a failed reply, for contrast',
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reply(
                _restarted(context),
                calls: const ToolCallGroup(calls: [cancelledToolCall]),
              ),
              const SizedBox(height: 24),
              _reply(
                const ReplyErrorNote(kReplyFailedMessage),
                calls: const ToolCallGroup(calls: failedToolRun),
              ),
            ],
          ),
        ),
        _case(
          'Long sentence wraps',
          (_) => const ReplyInterruptedNote(
            text:
                'Hermes restarted. This reply was interrupted. Whatever it '
                'wrote before that is kept above, and nothing was sent '
                'again.',
          ),
          width: 320,
        ),
        _case(
          'Long unconfirmed sentence wraps',
          (_) => const ReplyInterruptedNote(
            unconfirmed: true,
            text:
                "Couldn't confirm how this reply ended. It may have finished; "
                'check the conversation before trying again.',
          ),
          width: 320,
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: frame(_unconfirmed(context), maxWidth: 360),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, restarted',
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: frame(_restarted(context), maxWidth: 360),
          ),
        ),
      ],
    ),
  ],
);
