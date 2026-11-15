import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_reply.dart' show kReplyFailedMessage;
import 'package:hermes_app/src/chat/widgets/reply_error_note.dart';
import 'package:hermes_app/src/chat/widgets/reply_reconnecting_note.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

/// The note under a reply whose connection dropped while Hermes may still be
/// working on it. It takes the sentence, so the locale addon shows German too.
Widget _note(BuildContext context) =>
    ReplyReconnectingNote(text: context.l10n.chatReplyReconnecting);

WidgetbookUseCase _case(String name, WidgetBuilder builder, {double? width}) =>
    WidgetbookUseCase(
      name: name,
      builder: (context) => frame(builder(context), maxWidth: width ?? 480),
    );

/// A reply as the transcript draws it: the text, then its tool calls, then
/// what the reply says about itself.
Widget _reply(Widget tail, {required Widget calls}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text('Starting the build. This takes a few minutes.'),
    const SizedBox(height: 8),
    calls,
    tail,
  ],
);

WidgetbookFolder replyReconnectingNode() => WidgetbookFolder(
  name: 'ReplyReconnectingNote',
  children: [
    WidgetbookComponent(
      name: 'ReplyReconnectingNote',
      useCases: [
        _case('Alone', _note),
        _case(
          'Not trying any more',
          (context) =>
              ReplyReconnectingNote(text: context.l10n.chatReplyReconnectIdle),
        ),
        _case(
          'Not trying any more, under a running call',
          (context) => _reply(
            ReplyReconnectingNote(text: context.l10n.chatReplyReconnectIdle),
            calls: const ToolCallGroup(calls: [runningToolCall]),
          ),
        ),
        _case(
          'Under a reply with a running tool call',
          (context) => _reply(
            _note(context),
            calls: const ToolCallGroup(calls: [runningToolCall]),
          ),
        ),
        _case(
          'Under a reply with finished and running calls',
          (context) => _reply(
            _note(context),
            calls: const ToolCallGroup(calls: runningToolRun),
          ),
        ),
        _case(
          'Beside a failed reply, for contrast',
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reply(
                _note(context),
                calls: const ToolCallGroup(calls: [runningToolCall]),
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
          (_) => const ReplyReconnectingNote(
            text:
                'Connection lost. Reconnecting… Hermes may still be working on '
                'this, and the answer will appear here when the connection is '
                'back.',
          ),
          width: 320,
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: frame(_note(context), maxWidth: 360),
          ),
        ),
      ],
    ),
  ],
);
