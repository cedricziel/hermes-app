import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController, User;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;

import '../../bot_mode/bot_chat_context.dart';
import '../../bot_mode/widgets/bot_chat_banner.dart';
import '../../share/shared_item.dart';
import '../../theme/platform_chrome.dart';
import '../attachments/attachment_source.dart';
import '../attachments/attachment_surface.dart';
import '../chat_message_kinds.dart';
import '../chat_models.dart';
import '../chat_theme.dart';
import '../queued_prompt.dart';
import '../slash_command.dart';
import '../starter_prompts.dart';
import 'chat_builders.dart';
import '../../voice/dictation_controller.dart';
import 'chat_composer_builder.dart';
import 'message_actions.dart' show TurnActionStatus;
import '../chat_warning_state.dart';
import 'agent_notice_card.dart';
import '../chat_session_state.dart';
import 'session_status_card.dart';
import '../session_usage/session_usage_controller.dart';
import '../session_usage/session_usage_card.dart';
import '../todo_plan/todo_plan_card.dart';
import '../todo_plan/todo_plan_state.dart';
import '../side_results/side_result_card.dart';
import '../side_results/side_result_state.dart';
import '../connector_operation_controller.dart';
import 'connector_operation_card.dart';
import '../billing_verification_controller.dart';
import 'billing_verification_card.dart';
import '../reactions/reaction_cards.dart';
import '../reactions/reaction_state.dart';
import '../moa_progress_state.dart';
import 'moa_progress_card.dart';
import '../process_output_state.dart';
import 'process_output_card.dart';

/// The id of [thread]'s last message once it is a finished reply, the one
/// that can be asked again; null otherwise.
String? latestFinishedReplyId(ChatThread? thread) {
  final last = thread?.messages.lastOrNull;
  return last != null && last.role == ChatRole.assistant && !last.isPending
      ? last.id
      : null;
}

/// The open thread's messages and composer, in a column capped at
/// [kChatColumnMaxWidth]: the content of the main window's chat and of a
/// conversation window.
class ChatThreadView extends StatelessWidget {
  const ChatThreadView({
    super.key,
    required this.thread,
    this.botContext,
    required this.chatController,
    required this.composerController,
    required this.composerFocus,
    this.dictation,
    required this.attachments,
    required this.attachmentSource,
    required this.onAddAttachments,
    required this.onRemoveAttachment,
    required this.onSend,
    this.slashCommands = const [],
    this.commandRunning = false,
    this.queueView,
    this.sendTarget,
    this.starterPrompts,
    required this.onPickStarter,
    required this.latestReplyId,
    this.turnActionStatus,
    this.modelPill,
    this.header,
    this.notices = const [],
    this.onDismissNotice,
    this.onNoticeDetails,
    this.sessionState,
    this.sessionUsage,
    this.connectorOperations,
    this.connectionOperations,
    this.billingVerification,
    this.todoPlan,
    this.acknowledgement,
    this.reactionsFor,
    this.onReactionDetails,
    this.sideResults = const [],
    this.onSideResultDetails,
    this.moaProgress = const [],
    this.onMoaDetails,
    this.processOutputs,
    this.onProcessOutputDetails,
    this.onSessionDetails,
    this.onReopenSession,
    this.onRetry,
    this.onEdit,
    this.onLoadOlder,
    this.onAnswerApproval,
    this.onAnswerClarify,
    this.onSkipUnsupported,
    this.onAnswerVault,
    this.onStop,
    this.queued = const [],
    this.onRemoveQueued,
    this.onSendQueued,
    this.greetingName,
    this.welcome = true,
  });

  final ChatThread? thread;
  final List<AgentNotice> notices;
  final ValueChanged<AgentNotice>? onDismissNotice;
  final VoidCallback? onNoticeDetails;
  final ChatSessionState? sessionState;
  final SessionUsageController? sessionUsage;
  final ConnectorOperationController? connectorOperations, connectionOperations;
  final BillingVerificationController? billingVerification;
  final TodoPlanState? todoPlan;
  final SessionAcknowledgement? acknowledgement;
  final List<ReportedReaction>? Function(DurableReactionRow row)? reactionsFor;
  final VoidCallback? onReactionDetails;
  final List<SideResult> sideResults;
  final VoidCallback? onSideResultDetails;
  final List<MoaProgress> moaProgress;
  final VoidCallback? onMoaDetails;
  final ProcessOutputState? processOutputs;
  final VoidCallback? onProcessOutputDetails;
  final VoidCallback? onSessionDetails;
  final VoidCallback? onReopenSession;
  final BotChatContext? botContext;
  final InMemoryChatController chatController;
  final TextEditingController composerController;
  final FocusNode composerFocus;

  /// Dictation into the composer; none in a conversation window.
  final DictationController? dictation;
  final List<SharedFile> attachments;
  final AttachmentSource attachmentSource;
  final ValueChanged<List<SharedFile>> onAddAttachments;
  final ValueChanged<SharedFile> onRemoveAttachment;
  final ValueChanged<String> onSend;
  final List<SlashCommand> slashCommands;
  final bool commandRunning;
  final Widget? queueView;

  /// The chat a send goes to; a send held back for a dictation is dropped
  /// when this changed meanwhile.
  final Object? Function()? sendTarget;
  final List<StarterPrompt>? starterPrompts;
  final ValueChanged<StarterPrompt> onPickStarter;
  final ValueListenable<String?> latestReplyId;
  final ValueListenable<TurnActionStatus>? turnActionStatus;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final Widget? modelPill;

  /// Shown above the thread in a wide layout.
  final Widget? header;
  final Future<void> Function()? onLoadOlder;
  final Future<void> Function(String requestId, String choice)?
  onAnswerApproval;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onAnswerClarify;
  final Future<void> Function(String requestId, UnsupportedKind kind)?
  onSkipUnsupported;
  final Future<void> Function(
    String requestId,
    VaultKind kind, {
    String identifier,
    String password,
    String code,
  })?
  onAnswerVault;
  final Future<void> Function()? onStop;
  final List<QueuedPrompt> queued;
  final ValueChanged<QueuedPrompt>? onRemoveQueued;
  final VoidCallback? onSendQueued;

  /// The signed-in user's name for the welcome view's greeting.
  final String? greetingName;

  /// Whether an empty chat shows the welcome view; the quick panel shows
  /// just the composer instead.
  final bool welcome;

  Widget _connectorCards(
    ConnectorOperationController controller, {
    bool connectionWide = false,
  }) {
    final attachment = controller.attachment;
    return ConstrainedBox(
      key: ObjectKey(controller),
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (connectionWide) const Text('Connection activity'),
            for (final operation in controller.operations)
              ConnectorOperationCard(
                key: ValueKey(operation.key),
                operation: operation,
                readOnly: !controller.authorityFor(operation),
                pending: controller.pendingFor(operation.key),
                awaitingFinalStatus: controller.awaitingFinalStatus(
                  operation.key,
                ),
                error: controller.errorFor(operation.key),
                onDetails: controller.detailsOpened,
                canOpen: (name) => controller.canOpen(operation.key, name),
                canSkip: (name) => controller.canSkip(operation.key, name),
                onOpen: attachment == null
                    ? null
                    : (name) => unawaited(
                        controller.openTarget(
                          operation,
                          name,
                          attachment: attachment,
                        ),
                      ),
                onSkip: attachment == null
                    ? null
                    : (name) => unawaited(
                        controller.skip(
                          operation,
                          name,
                          attachment: attachment,
                        ),
                      ),
                onContinue:
                    attachment == null || !controller.canRespond(operation.key)
                    ? null
                    : () => unawaited(
                        controller.continueOperation(
                          operation,
                          attachment: attachment,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builders =
        buildChatBuilders(
          starterPrompts: starterPrompts,
          onPickPrompt: onPickStarter,
          greetingName: greetingName,
          assistantName: botContext?.title,
          latestReplyId: latestReplyId,
          turnActionStatus: turnActionStatus,
          onRetry: onRetry,
          onEdit: onEdit,
          onLoadOlder: onLoadOlder,
          onAnswerApproval: onAnswerApproval,
          onAnswerClarify: onAnswerClarify,
          onSkipUnsupported: onSkipUnsupported,
          onAnswerVault: onAnswerVault,
          reactionsFor: reactionsFor,
          onReactionDetails: onReactionDetails,
        ).copyWith(
          composerBuilder: buildChatComposer(
            controller: composerController,
            focusNode: composerFocus,
            dictation: dictation,
            botContext: botContext,
            attachments: attachments,
            onRemoveAttachment: onRemoveAttachment,
            replying: thread?.isReplying == true,
            onStop: thread?.isReplying == true ? onStop : null,
            queued: queued,
            onRemoveQueued: onRemoveQueued,
            onSendQueued: onSendQueued,
            modelPill: modelPill,
            slashCommands: slashCommands,
            commandRunning: commandRunning,
            queueView: queueView,
            sendTarget: sendTarget,
          ),
        );
    // copyWith takes a null builder as "none", so only the panel's case
    // replaces the welcome view.
    final shown = welcome
        ? builders
        : builders.copyWith(
            emptyChatListBuilder: (_) => const SizedBox.shrink(),
          );

    List<Widget> activity() => [
      if (connectionOperations case final operations?
          when operations.operations.isNotEmpty)
        _connectorCards(operations, connectionWide: true),
      if (connectorOperations case final operations?
          when operations.operations.isNotEmpty)
        _connectorCards(operations),
      if (billingVerification case final billing? when billing.supported)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: BillingVerificationCard(
              key: ObjectKey(billing),
              controller: billing,
            ),
          ),
        ),
      if (acknowledgement != null)
        SessionAcknowledgementCard(
          acknowledgement: acknowledgement,
          onDetails: onReactionDetails,
        ),
      if (sessionState case final state? when state.visible)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: SessionStatusCard(
              state: state,
              onDetails: onSessionDetails,
              onReopen: onReopenSession,
            ),
          ),
        ),
      if (sessionUsage case final usage? when usage.shown)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: SessionUsageCard(key: ObjectKey(usage), controller: usage),
          ),
        ),
      if (processOutputs case final processes? when processes.cards.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final process in processes.cards)
                  ProcessOutputCard(
                    key: ValueKey(process.processId),
                    output: process,
                    onDetails: onProcessOutputDetails,
                  ),
                if (processes.omittedCards)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Earlier process cards omitted.'),
                  ),
              ],
            ),
          ),
        ),
      if (todoPlan case final plan? when plan.hasPlan)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: TodoPlanCard(key: ObjectKey(plan), state: plan),
          ),
        ),
      if (moaProgress.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final progress in moaProgress)
                MoaProgressCard(
                  key: ObjectKey(progress.turn),
                  progress: progress,
                  onDetails: onMoaDetails,
                ),
            ],
          ),
        ),
      if (sideResults.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final result in sideResults)
                  SideResultCard(
                    key: ValueKey((result.kind, result.taskId)),
                    result: result,
                    onDetails: onSideResultDetails,
                  ),
              ],
            ),
          ),
        ),
      if (notices.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final notice in notices)
                AgentNoticeCard(
                  key: ObjectKey(notice),
                  notice: notice,
                  onDismiss: onDismissNotice == null
                      ? null
                      : () => onDismissNotice!(notice),
                  onDetails: onNoticeDetails,
                ),
            ],
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (header case final header?) ...[
            header,
            if (platformChromeOf(context) != PlatformChrome.macos)
              const Divider(height: 1),
          ],
          if (botContext case final bot?) BotChatBanner(context: bot),
          // Cards come and go with their controllers, not with this view.
          ListenableBuilder(
            listenable: Listenable.merge([
              billingVerification,
              sessionUsage,
              todoPlan,
            ]),
            builder: (context, _) {
              final cards = activity();
              if (cards.isEmpty) return const SizedBox.shrink();
              return ConstrainedBox(
                key: const Key('chat-activity-strip'),
                constraints: BoxConstraints(
                  maxHeight: constraints.hasBoundedHeight
                      ? math.min(280.0, constraints.maxHeight * 0.4)
                      : 280,
                ),
                child: SingleChildScrollView(child: Column(children: cards)),
              );
            },
          ),
          Expanded(
            child: AttachmentSurface(
              source: attachmentSource,
              onAdd: onAddAttachments,
              builder: (context, openAttachMenu) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kChatColumnMaxWidth,
                  ),
                  child: SizedBox.expand(
                    child: FlyerMaterialScope(
                      child: Chat(
                        // The controller too: after a profile switch the same
                        // id names another thread.
                        key: ValueKey((thread?.id, chatController)),
                        chatController: chatController,
                        currentUserId: kUserAuthorId,
                        resolveUser: (id) async => User(id: id),
                        onMessageSend: onSend,
                        onAttachmentTap: openAttachMenu,
                        theme: buildChatTheme(Theme.of(context)),
                        builders: shown,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
