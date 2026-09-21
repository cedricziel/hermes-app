import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController, User;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_theme.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:provider/provider.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';

final _at = DateTime.now();

ChatMessage _user(String id, String text, {List<ChatAttachment>? files}) =>
    ChatMessage(
      id: id,
      role: ChatRole.user,
      content: text,
      createdAt: _at,
      attachments: files ?? const [],
    );

ChatMessage _reply(
  String id,
  String text, {
  MessageStatus status = MessageStatus.sent,
  List<ToolCall> tools = const [],
  List<InputRequest> requests = const [],
  String reasoning = '',
}) => ChatMessage(
  id: id,
  role: ChatRole.assistant,
  content: text,
  createdAt: _at,
  status: status,
  toolCalls: tools,
  inputRequests: requests,
  reasoning: reasoning,
);

const _markdown =
    'The job hit a `ConnectionResetError` while uploading the checkpoint.\n\n'
    '- the retry policy gave up after 3 attempts\n'
    '- the backoff cap is lower than the network latency\n\n'
    '```python\nRETRY_BACKOFF_CAP_S = 8  # too low for this host\n```\n\n'
    'Bumping it to 30 s should cover it. Want me to open a PR?';

/// The real chat: flutter_chat_ui with Hermes' builders, theme and composer,
/// fed by the same message mapping the chat screen uses.
class _ChatThreadView extends StatefulWidget {
  const _ChatThreadView({
    required this.messages,
    this.attachments = const [],
    this.replying = false,
    this.canRetry = true,
  });

  final List<ChatMessage> messages;
  final List<SharedFile> attachments;
  final bool replying;
  final bool canRetry;

  @override
  State<_ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<_ChatThreadView> {
  late final InMemoryChatController _controller = InMemoryChatController(
    messages: [for (final m in widget.messages) ...chatMessageToFlyer(m)],
  );
  final _text = TextEditingController();
  late final _latest = ValueNotifier<String?>(
    widget.messages.where((m) => m.role == ChatRole.assistant).lastOrNull?.id,
  );

  @override
  void dispose() {
    _controller.dispose();
    _text.dispose();
    _latest.dispose();
    super.dispose();
  }

  Future<void> _answered(String requestId, Object? _) async {}

  @override
  Widget build(BuildContext context) {
    return Provider<MediaStore?>.value(
      value: null,
      child: FlyerMaterialScope(
        child: SelectionArea(
          child: Chat(
            chatController: _controller,
            currentUserId: kUserAuthorId,
            resolveUser: (id) async => User(id: id),
            onMessageSend: (_) {},
            theme: buildChatTheme(Theme.of(context)),
            builders:
                buildChatBuilders(
                  greetingName: 'Ada',
                  onPickPrompt: (_) {},
                  latestReplyId: _latest,
                  onRetry: widget.canRetry ? () {} : null,
                  onAnswerApproval: _answered,
                  onAnswerClarify: _answered,
                  onSkipUnsupported: _answered,
                ).copyWith(
                  composerBuilder: buildChatComposer(
                    controller: _text,
                    attachments: widget.attachments,
                    onRemoveAttachment: (_) {},
                    onStop: widget.replying ? () async {} : null,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

WidgetbookUseCase _thread(
  String name,
  List<ChatMessage> messages, {
  List<SharedFile> attachments = const [],
  bool replying = false,
  bool canRetry = true,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => _ChatThreadView(
    messages: messages,
    attachments: attachments,
    replying: replying,
    canRetry: canRetry,
  ),
);

WidgetbookNode chatThreadNode() => WidgetbookFolder(
  name: 'Chat thread',
  children: [
    WidgetbookComponent(
      name: 'Messages',
      useCases: [
        _thread('Empty, welcome', const []),
        _thread('Conversation', [
          _user('u1', 'Why did the run fail around 02:14?'),
          _reply('a1', _markdown, tools: const [finishedToolCall]),
        ]),
        _thread('Thinking', [
          _user('u1', 'Why did the run fail around 02:14?'),
          _reply('a1', '', status: MessageStatus.thinking),
        ], replying: true),
        _thread('Streaming with a tool running', [
          _user('u1', 'Run the tests'),
          _reply(
            'a1',
            'Running the suite now, this takes a moment',
            status: MessageStatus.streaming,
            tools: const [runningToolCall],
          ),
        ], replying: true),
        _thread('Reasoning and tools', [
          _user('u1', 'Delete the build folder'),
          _reply(
            'a1',
            'Done.',
            reasoning: reasoningText,
            tools: const [finishedToolCall, failedToolCall],
          ),
        ]),
        _thread('Failed reply', [
          _user('u1', 'Summarise the weekly report'),
          _reply(
            'a1',
            'Something went wrong. Try again.',
            status: MessageStatus.error,
          ),
        ]),
        _thread('Failed reply that cannot be retried', [
          _user('u1', 'Summarise the weekly report'),
          _reply('a1', 'Something went wrong.', status: MessageStatus.error),
        ], canRetry: false),
        _thread('Attachments', [
          _user(
            'u1',
            'Here is the report',
            files: const [pdfAttachment, relativeAttachment],
          ),
          _reply('a1', 'I read both files.'),
        ]),
      ],
    ),
    WidgetbookComponent(
      name: 'Input requests',
      useCases: [
        _thread('Approval', [
          _user('u1', 'Clean up'),
          _reply('a1', '', requests: [pendingApproval]),
        ]),
        _thread('Clarify', [
          _user('u1', 'Deploy it'),
          _reply('a1', '', requests: [singleChoiceClarify]),
        ]),
        _thread('Several questions', [
          _user('u1', 'Prepare the release'),
          _reply('a1', '', requests: [batchClarify]),
        ]),
        _thread('Unsupported request', [
          _user('u1', 'Install the package'),
          _reply('a1', '', requests: [sudoRequest]),
        ]),
        _thread('Answered', [
          _user('u1', 'Clean up'),
          _reply('a1', 'Deleted.', requests: [answeredApproval]),
        ]),
      ],
    ),
    WidgetbookComponent(
      name: 'Composer',
      useCases: [
        _thread('Empty', const []),
        _thread(
          'With attachments',
          const [],
          attachments: const [
            SharedFile(path: '/tmp/report.pdf', name: 'report.pdf'),
            SharedFile(
              path: '/tmp/chart.png',
              name: 'chart.png',
              isImage: true,
            ),
          ],
        ),
        _thread('Reply in flight, stop bar', [
          _user('u1', 'Run the tests'),
          _reply('a1', 'Running', status: MessageStatus.streaming),
        ], replying: true),
      ],
    ),
  ],
);
