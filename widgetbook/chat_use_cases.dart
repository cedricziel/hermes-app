import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/queued_prompt.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/queued_prompts.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/chat/widgets/unsupported_request_card.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:provider/provider.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

Future<void> _answers(Object? _) =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _fails(Object? _) async => throw StateError('offline');

Future<void> _skips() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _skipFails() async => throw StateError('offline');

Widget _noStore(Widget child) =>
    Provider<MediaStore?>.value(value: null, child: child);

const _queued = [
  QueuedPrompt('Then bump the backoff cap to 30 s and open a PR.', []),
  QueuedPrompt('Also check whether the nightly job uses the same policy.', [
    SharedFile(path: '/tmp/nightly.yaml', name: 'nightly.yaml'),
  ]),
  QueuedPrompt('', [
    SharedFile(path: '/tmp/trace.png', name: 'trace.png', isImage: true),
  ]),
];

WidgetbookUseCase _tool(String name, Widget card) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(card));

WidgetbookNode chatNode() => WidgetbookFolder(
  name: 'Chat',
  children: [
    WidgetbookComponent(
      name: 'ToolCallCard',
      useCases: [
        _tool('Running', const ToolCallCard(call: runningToolCall)),
        _tool('Finished', const ToolCallCard(call: finishedToolCall)),
        _tool('Failed', const ToolCallCard(call: failedToolCall)),
      ],
    ),
    WidgetbookComponent(
      name: 'ToolCallGroup',
      useCases: [
        _tool('Single call', const ToolCallGroup(calls: [runningToolCall])),
        _tool('Finished run', const ToolCallGroup(calls: finishedToolRun)),
        _tool('Running', const ToolCallGroup(calls: runningToolRun)),
        _tool('Failed', const ToolCallGroup(calls: failedToolRun)),
      ],
    ),
    WidgetbookComponent(
      name: 'ChatHeader',
      useCases: [
        _tool('No thread', ChatHeader(thread: null, onShowConnection: () {})),
        _tool(
          'Thread on the server',
          ChatHeader(thread: threads[0], onShowConnection: () {}),
        ),
        _tool(
          'Local thread',
          ChatHeader(thread: threads[2], onShowConnection: () {}),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ThreadActionsButton',
      useCases: [
        _tool(
          'Local thread: copy transcript only',
          ThreadActionsButton(thread: threads[2], includeCopyTranscript: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ApprovalCard',
      useCases: [
        _tool(
          'Pending',
          ApprovalCard(request: pendingApproval, onAnswer: _answers),
        ),
        _tool(
          'Answer fails',
          ApprovalCard(request: pendingApproval, onAnswer: _fails),
        ),
        _tool('Answered', ApprovalCard(request: answeredApproval)),
        _tool('Expired', ApprovalCard(request: expiredApproval)),
      ],
    ),
    WidgetbookComponent(
      name: 'ClarifyCard',
      useCases: [
        _tool(
          'Choices',
          ClarifyCard(request: singleChoiceClarify, onAnswer: _answers),
        ),
        _tool(
          'Free text',
          ClarifyCard(request: openClarify, onAnswer: _answers),
        ),
        _tool(
          'Several questions',
          ClarifyCard(request: batchClarify, onAnswer: _answers),
        ),
        _tool('Answered', ClarifyCard(request: answeredClarify)),
      ],
    ),
    WidgetbookComponent(
      name: 'UnsupportedRequestCard',
      useCases: [
        _tool(
          'Secret',
          UnsupportedRequestCard(request: secretRequest, onSkip: _skips),
        ),
        _tool(
          'Sudo',
          UnsupportedRequestCard(request: sudoRequest, onSkip: _skips),
        ),
        _tool(
          'Skip fails',
          UnsupportedRequestCard(request: secretRequest, onSkip: _skipFails),
        ),
        _tool('Skipped', UnsupportedRequestCard(request: skippedSecretRequest)),
        _tool('Expired', UnsupportedRequestCard(request: expiredSecretRequest)),
      ],
    ),
    WidgetbookComponent(
      name: 'ReasoningBlock',
      useCases: [
        _tool('Folded', const ReasoningBlock(text: reasoningText)),
        _tool(
          'Still reasoning',
          const ReasoningBlock(text: reasoningText, active: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'WelcomeView',
      useCases: [
        WidgetbookUseCase(
          name: 'Greeting with name',
          builder: (_) => WelcomeView(greetingName: 'Ada', onPick: (_) {}),
        ),
        WidgetbookUseCase(
          name: 'No name',
          builder: (_) => WelcomeView(greetingName: null, onPick: (_) {}),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'MessageActions',
      useCases: [
        _tool('Copy', const MessageActions(text: 'The build finished.')),
        _tool(
          'Copy and retry',
          MessageActions(text: 'The build finished.', onRetry: () {}),
        ),
        _tool(
          'Retry only (failed reply)',
          MessageActions(text: 'Timed out', showCopy: false, onRetry: () {}),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'AttachmentCard',
      useCases: [
        _tool(
          'With size',
          _noStore(const AttachmentCard(attachment: pdfAttachment)),
        ),
        _tool(
          'Size unknown',
          _noStore(const AttachmentCard(attachment: relativeAttachment)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'QueuedPrompts',
      useCases: [
        _tool(
          'Waiting for the reply',
          QueuedPrompts(prompts: _queued.sublist(0, 1), onRemove: (_) {}),
        ),
        _tool(
          'Several, with attachments',
          QueuedPrompts(prompts: _queued, onRemove: (_) {}),
        ),
        _tool(
          'Paused after a stop',
          QueuedPrompts(
            prompts: _queued.sublist(0, 2),
            onRemove: (_) {},
            onSendNow: () {},
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ChatComposer',
      useCases: [
        _composer('Empty'),
        _composer('Text', text: 'Why did the nightly upload fail?'),
        _composer(
          'With attachments',
          attachments: const [
            SharedFile(path: '/tmp/report.pdf', name: 'report.pdf'),
            SharedFile(
              path: '/tmp/chart.png',
              name: 'chart.png',
              isImage: true,
            ),
          ],
        ),
        _composer('Replying with a queue', replying: true, queued: _queued),
        _composer('No model pill', pill: false),
      ],
    ),
    WidgetbookComponent(
      name: 'ThinkingIndicator',
      useCases: [
        _tool(
          'Thinking',
          ThinkingIndicator(
            startedAt: DateTime.now().subtract(const Duration(seconds: 4)),
            activity: 'Thinking…',
          ),
        ),
        _tool(
          'Running a tool, over a minute in',
          ThinkingIndicator(
            startedAt: DateTime.now().subtract(
              const Duration(minutes: 1, seconds: 12),
            ),
            activity: 'Running git_show…',
          ),
        ),
      ],
    ),
  ],
);

WidgetbookUseCase _composer(
  String name, {
  String text = '',
  List<SharedFile> attachments = const [],
  bool replying = false,
  List<QueuedPrompt> queued = const [],
  bool pill = true,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => frame(
    _Composer(
      text: text,
      attachments: attachments,
      replying: replying,
      queued: queued,
      pill: pill,
    ),
    maxWidth: 760,
  ),
);

class _Composer extends StatefulWidget {
  const _Composer({
    required this.text,
    required this.attachments,
    required this.replying,
    required this.queued,
    required this.pill,
  });

  final String text;
  final List<SharedFile> attachments;
  final bool replying;
  final List<QueuedPrompt> queued;
  final bool pill;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatComposer(
    controller: _text,
    onSend: (_) => _text.clear(),
    onAttach: () {},
    attachments: widget.attachments,
    onRemoveAttachment: (_) {},
    replying: widget.replying,
    onStop: widget.replying ? () => _skips() : null,
    queued: widget.queued,
    onRemoveQueued: (_) {},
    modelPill: widget.pill
        ? ComposerModelPill(
            options: modelOptions,
            choice: null,
            onChanged: (_) {},
          )
        : null,
  );
}
