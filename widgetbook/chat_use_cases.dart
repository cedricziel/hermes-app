import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/attachments/draggable_attachment.dart';
import 'package:hermes_app/src/chat/chat_models.dart'
    show AttachmentKind, ChatAttachment, ThreadSearchHit, ToolCallStatus;
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/queued_prompt.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/chat/starter_prompts.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/chat_app_bar.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/voice/dictation_view.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/chat/chat_reply.dart' show kReplyFailedMessage;
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/reply_error_note.dart';
import 'package:hermes_app/src/chat/widgets/queued_prompts.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/chat/widgets/review_summary_note.dart';
import 'package:hermes_app/src/chat/widgets/subagent_card.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/chat/widgets/sidebar_row.dart';
import 'package:hermes_app/src/chat/widgets/swipeable_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_search_view.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/chat/widgets/unsupported_request_card.dart';
import 'package:hermes_app/src/chat/widgets/vault_request_card.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:provider/provider.dart';
import 'package:widgetbook/widgetbook.dart';

import 'catalog_drag_out_source.dart';
import 'fixtures.dart';
import 'frame.dart';

Future<void> _answers(Object? _) =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _fails(Object? _) async => throw StateError('offline');

Future<void> _skips() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _skipFails() async => throw StateError('offline');

Future<void> _vaultAnswers(String identifier, String password, String code) =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _vaultFails(
  String identifier,
  String password,
  String code,
) async => throw StateError('offline');

// A file whose bytes the message holds, so it can be dragged out.
final _draggableAttachment = ChatAttachment(
  name: 'quarterly-report.pdf',
  kind: AttachmentKind.file,
  size: 482113,
  bytes: Uint8List(8),
);

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

WidgetbookUseCase _phoneBar(String name, TargetPlatform platform) =>
    WidgetbookUseCase(
      name: name,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(platform: platform),
        child: Builder(
          builder: (context) => Scaffold(
            appBar: buildChatAppBar(
              context,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open navigation menu',
                onPressed: () {},
              ),
              title: Text(threads[0].title),
              actions: [NewChatButton(onPressed: () {})],
            ),
          ),
        ),
      ),
    );

WidgetbookUseCase _tool(String name, Widget card) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(card));

WidgetbookNode chatNode() => WidgetbookFolder(
  name: 'Chat',
  children: [
    WidgetbookComponent(
      name: 'ToolCallCard',
      useCases: [
        _tool('Running', const ToolCallCard(call: runningToolCall)),
        _tool('Running, timed', ToolCallCard(call: timedToolCall())),
        _tool('Preparing', const ToolCallCard(call: preparingToolCall)),
        _tool('Finished', const ToolCallCard(call: finishedToolCall)),
        _tool('Failed', const ToolCallCard(call: failedToolCall)),
        _tool('Cancelled', const ToolCallCard(call: cancelledToolCall)),
        _tool(
          'Waiting on approval',
          ToolCallCard(
            call: approvalToolCall,
            approval: pendingApproval,
            onAnswerApproval: (_) async {},
          ),
        ),
        _tool(
          'Approval answered',
          ToolCallCard(
            call: approvalToolCall.withStatus(ToolCallStatus.completed),
            approval: pendingApproval.answered('once'),
            initiallyOpen: true,
          ),
        ),
        _tool(
          'Terminal',
          const ToolCallCard(call: terminalToolCall, initiallyOpen: true),
        ),
        _tool(
          'Web search',
          const ToolCallCard(call: webSearchToolCall, initiallyOpen: true),
        ),
        _tool(
          'Todo list',
          const ToolCallCard(call: todoToolCall, initiallyOpen: true),
        ),
        _tool(
          'Diff',
          const ToolCallCard(call: diffToolCall, initiallyOpen: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ToolCallGroup',
      useCases: [
        _tool('Single call', const ToolCallGroup(calls: [runningToolCall])),
        _tool('Finished run', const ToolCallGroup(calls: finishedToolRun)),
        _tool('Running', const ToolCallGroup(calls: runningToolRun)),
        _tool('Failed', const ToolCallGroup(calls: failedToolRun)),
        _tool('Cancelled', const ToolCallGroup(calls: cancelledToolRun)),
        _tool(
          'Waiting on approval',
          ToolCallGroup(
            calls: waitingToolRun,
            approvals: const {1: pendingApproval},
            onAnswerApproval: (_, _) async {},
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SubagentGroupCard',
      useCases: [
        _tool('Running', SubagentGroupCard(subagents: [timedSubagent()])),
        _tool(
          'Finished',
          const SubagentGroupCard(subagents: [completedSubagent]),
        ),
        _tool('Failed', const SubagentGroupCard(subagents: [failedSubagent])),
        _tool(
          'Batch, collapsed',
          const SubagentGroupCard(subagents: subagentBatch),
        ),
        _tool(
          'Batch, open',
          const SubagentGroupCard(
            subagents: subagentBatch,
            initiallyOpen: true,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ReviewSummaryNote',
      useCases: [
        _tool('Memory', const ReviewSummaryNote(items: ['Memory updated'])),
        _tool(
          'Several changes',
          const ReviewSummaryNote(
            items: [
              'Memory updated',
              'User profile updated',
              "Skill 'deploy' patched",
            ],
          ),
        ),
        _tool(
          'Verbose, wrapping',
          const ReviewSummaryNote(
            items: [
              'Memory + Prefers short answers and metric units in every reply',
              "Skill 'release-notes' patched: \"Draft first\" → \"Draft, then check the tag\"",
            ],
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ChatHeader',
      useCases: [
        _tool(
          'No thread',
          ChatHeader(thread: null, onShowConnection: () {}, onNewChat: () {}),
        ),
        _tool(
          'Thread on the server',
          ChatHeader(
            thread: threads[0],
            onShowConnection: () {},
            onNewChat: () {},
          ),
        ),
        _tool(
          'Local thread',
          ChatHeader(
            thread: threads[2],
            onShowConnection: () {},
            onNewChat: () {},
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ChatAppBar',
      useCases: [
        _phoneBar('iOS', TargetPlatform.iOS),
        _phoneBar('Material (Android)', TargetPlatform.android),
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
      name: 'SwipeableThreadRow',
      useCases: [
        for (final (name, pinned) in [('Unpinned', false), ('Pinned', true)])
          WidgetbookUseCase(
            name: name,
            builder: (_) => frame(
              SwipeableThreadRow(
                title: 'Release notes',
                pinned: pinned,
                onAction: (_) {},
                child: SidebarRow(
                  selected: false,
                  onTap: () {},
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: const Text('Release notes'),
                ),
              ),
              maxWidth: 300,
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'ThreadSearchField',
      useCases: [
        for (final (name, query) in [('Empty', ''), ('With query', 'backup')])
          WidgetbookUseCase(
            name: name,
            builder: (_) =>
                frame(ThreadSearchField(query: query, onChanged: (_) {})),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'ThreadSearchResults',
      useCases: [
        for (final (name, status, hits) in [
          ('Results', ThreadSearchStatus.done, searchHits),
          ('Searching', ThreadSearchStatus.loading, <ThreadSearchHit>[]),
          ('No match', ThreadSearchStatus.done, <ThreadSearchHit>[]),
          ('Failed', ThreadSearchStatus.failed, <ThreadSearchHit>[]),
        ])
          WidgetbookUseCase(
            name: name,
            builder: (_) => fill(
              ThreadSearchResults(
                query: 'backup',
                status: status,
                hits: hits,
                selectedId: 'thread-2',
                onOpen: (_) {},
              ),
              width: 300,
            ),
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
      name: 'VaultRequestCard',
      useCases: [
        _tool(
          'Save login',
          VaultRequestCard(request: saveLoginRequest, onAnswer: _vaultAnswers),
        ),
        _tool(
          'Save fails',
          VaultRequestCard(request: saveLoginRequest, onAnswer: _vaultFails),
        ),
        _tool(
          'Unlock manager',
          VaultRequestCard(
            request: vaultUnlockRequest,
            onAnswer: _vaultAnswers,
          ),
        ),
        _tool(
          'One-time code',
          VaultRequestCard(request: vaultCodeRequest, onAnswer: _vaultAnswers),
        ),
        _tool('Answered', VaultRequestCard(request: answeredVaultCodeRequest)),
        _tool('Declined', VaultRequestCard(request: declinedSaveLoginRequest)),
        _tool('Expired', VaultRequestCard(request: expiredSaveLoginRequest)),
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
          name: 'Generic prompts',
          builder: (_) => WelcomeView(
            greetingName: 'Ada',
            prompts: buildStarterPrompts(const StarterContext()),
            onPick: (_) {},
          ),
        ),
        WidgetbookUseCase(
          name: 'Full context',
          builder: (_) => WelcomeView(
            greetingName: 'Ada',
            prompts: buildStarterPrompts(
              const StarterContext(
                failedJob: 'Nightly backup',
                kanbanTask: StarterTask(
                  'Move the auth service to the new OIDC provider and retire '
                  'the old password endpoint',
                  blocked: true,
                ),
                recentChat: StarterChat(id: 't1', title: 'Telegram pairing'),
                skill: 'nextcloud-notes',
              ),
            ),
            onPick: (_) {},
          ),
        ),
        WidgetbookUseCase(
          name: 'Kanban off, no name',
          builder: (_) => WelcomeView(
            greetingName: null,
            prompts: buildStarterPrompts(
              const StarterContext(
                failedJob: 'Nightly backup',
                recentChat: StarterChat(id: 't1', title: 'Telegram pairing'),
                skill: 'nextcloud-notes',
              ),
            ),
            onPick: (_) {},
          ),
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
          'Copy, retry and edit',
          MessageActions(
            text: 'The build finished.',
            onRetry: () {},
            onEdit: () {},
          ),
        ),
        _tool(
          'Retry only (failed reply)',
          MessageActions(text: 'Timed out', showCopy: false, onRetry: () {}),
        ),
        _tool(
          'Stopped by the user',
          MessageActions(text: 'The job hit a', stopped: true, onRetry: () {}),
        ),
        _tool(
          'Trying again',
          MessageActions(
            text: 'Timed out',
            showCopy: false,
            onRetry: () {},
            status: const TurnActionStatus(running: TurnAction.retry),
          ),
        ),
        _tool(
          'Taking the prompt back',
          MessageActions(
            text: 'The build finished.',
            onRetry: () {},
            onEdit: () {},
            status: const TurnActionStatus(running: TurnAction.edit),
          ),
        ),
        _tool(
          'Try again failed',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ReplyErrorNote(kReplyFailedMessage),
              MessageActions(
                text: 'Timed out',
                showCopy: false,
                onRetry: () {},
                status: const TurnActionStatus(
                  problem: "Couldn't reach Hermes to try again. Check your connection.",
                ),
              ),
            ],
          ),
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
        _tool(
          'Draggable on macOS (hover shows the file name)',
          withCatalogDragOut(
            _noStore(
              DraggableAttachment(
                attachment: _draggableAttachment,
                child: AttachmentCard(attachment: _draggableAttachment),
              ),
            ),
          ),
        ),
        _tool(
          'Not downloadable, so not draggable',
          withCatalogDragOut(
            _noStore(
              const DraggableAttachment(
                attachment: relativeAttachment,
                child: AttachmentCard(attachment: relativeAttachment),
              ),
            ),
          ),
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
          'Slash suggestions',
          text: '/he',
          slashCommands: const [
            SlashCommand('/help', 'Show available commands'),
          ],
        ),
        _composer('Command running', text: '/help', commandRunning: true),
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
        _composer('Dictation, idle', dictation: DictationPhase.idle),
        _composer('Dictation, recording', dictation: DictationPhase.recording),
        _composer(
          'Dictation, words in the field',
          text: 'Please $dictationLiveTranscript',
          dictation: DictationPhase.recording,
        ),
        _composer(
          'Dictation, through Hermes',
          text: 'Please',
          dictation: DictationPhase.recording,
          engine: DictationEngine.hermes,
        ),
        _composer(
          'Dictation, transcribing',
          text: 'Please $dictationLiveTranscript',
          dictation: DictationPhase.settling,
        ),
        _composer('Dictation failed', dictation: DictationPhase.failed),
        _composer('Dictation, no speech', dictation: DictationPhase.noSpeech),
        _composer('Dictation, no microphone', dictation: DictationPhase.denied),
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
  List<SlashCommand> slashCommands = const [],
  bool commandRunning = false,
  DictationPhase? dictation,
  DictationEngine engine = DictationEngine.device,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => frame(
    _Composer(
      dictation: dictation == null
          ? null
          : DictationView(
              phase: dictation,
              levels: dictationLevels,
              elapsed: const Duration(seconds: 9),
              canRetry: dictation == DictationPhase.failed,
              engine: engine,
              onSend: () {},
              onStart: () {},
              onStop: () {},
              onCancel: () {},
              onRetry: () {},
              onDismiss: () {},
            ),
      text: text,
      attachments: attachments,
      replying: replying,
      queued: queued,
      pill: pill,
      slashCommands: slashCommands,
      commandRunning: commandRunning,
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
    required this.slashCommands,
    required this.commandRunning,
    this.dictation,
  });

  final DictationView? dictation;

  final String text;
  final List<SharedFile> attachments;
  final bool replying;
  final List<QueuedPrompt> queued;
  final bool pill;
  final List<SlashCommand> slashCommands;
  final bool commandRunning;

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
    slashCommands: widget.slashCommands,
    commandRunning: widget.commandRunning,
    dictation: widget.dictation,
    modelPill: widget.pill
        ? ComposerModelPill(
            options: modelOptions,
            choice: null,
            onChanged: (_) {},
          )
        : null,
  );
}
