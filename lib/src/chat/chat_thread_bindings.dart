import 'package:flutter/widgets.dart';

import '../models/widgets/composer_model_pill.dart';
import '../share/shared_item.dart';
import '../voice/dictation_controller.dart';
import 'attachments/attachment_source.dart';
import 'chat_controller.dart';
import 'widgets/queued_prompts.dart';
import 'chat_models.dart';
import 'slash_command.dart';
import 'starter_prompts.dart';
import 'widgets/chat_thread_view.dart';
import 'widgets/message_actions.dart' show TurnActionStatus;

/// The model pill for [chat]'s composer; null while there are no options to
/// pick from.
Widget? composerModelPill(ChatController chat) {
  final options = chat.modelOptions;
  if (options == null || options.providers.isEmpty) return null;
  return ComposerModelPill(
    options: options,
    choice: chat.modelChoice,
    onChanged: chat.chooseModel,
  );
}

/// The files of [picked] that [attachments] does not hold yet.
List<SharedFile> newAttachments(
  List<SharedFile> attachments,
  List<SharedFile> picked,
) => [
  for (final file in picked)
    if (!attachments.contains(file)) file,
];

/// The latest finished reply of the shown chat and what its turn actions
/// may do, which the chat's message actions follow.
class LatestReply {
  final id = ValueNotifier<String?>(null);
  final status = ValueNotifier(TurnActionStatus.idle);
  var _disposed = false;

  /// Follows [thread] of [chat]; called from build, so the notifiers change
  /// after the frame.
  void follow(ChatController chat, ChatThread? thread) {
    final latest = latestFinishedReplyId(thread);
    final turn = thread == null
        ? TurnActionStatus.idle
        : chat.turnActionStatus(thread);
    if (id.value == latest && status.value == turn) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      id.value = latest;
      status.value = turn;
    });
  }

  void dispose() {
    _disposed = true;
    id.dispose();
    status.dispose();
  }
}

Widget? protectedQueueView(ChatController chat, ChatThread? t) =>
    t == null ||
        chat.queueStore == null ||
        chat.queuedIn(t).isEmpty &&
            chat.queueErrorIn(t) == null &&
            !chat.queueBusy(t) &&
            chat.queuesVisible
    ? null
    : QueuedPrompts(
        prompts: chat.queuedIn(t),
        busy: chat.queueBusy(t),
        reviewRequired: chat.queueNeedsReview(t),
        available: chat.queueAvailable(t),
        locked: !chat.queuesVisible,
        storageError: chat.queueErrorIn(t),
        onRemove: (prompt) => chat.removeQueued(t, prompt),
        onSendNow:
            chat.queuePaused(t) && !chat.queueBusy(t) && chat.queueAvailable(t)
            ? () => chat.sendQueued(t)
            : null,
        onInspect: () => chat.inspectQueued(t),
      );

/// [ChatThreadView] for [thread] of [chat], with the chat's answers,
/// retries, paging and queue bound to [chat]. A null [thread] (a new chat)
/// has none of them. Only the main window lets the last prompt be edited
/// ([editable]) and offers [starterPrompts], slash commands and a [header].
ChatThreadView boundChatThreadView({
  required ChatController chat,
  required ChatThread? thread,
  required TextEditingController composerController,
  required FocusNode composerFocus,
  DictationController? dictation,
  required List<SharedFile> attachments,
  required AttachmentSource attachmentSource,
  required ValueChanged<List<SharedFile>> onAddAttachments,
  required ValueChanged<SharedFile> onRemoveAttachment,
  required ValueChanged<String> onSend,
  required LatestReply latestReply,
  bool welcome = true,
  bool editable = false,
  String? greetingName,
  Object? Function()? sendTarget,
  List<SlashCommand> slashCommands = const [],
  bool commandRunning = false,
  List<StarterPrompt>? starterPrompts,
  ValueChanged<StarterPrompt>? onPickStarter,
  Widget? header,
  Widget? recipientChip,
}) {
  final t = thread;
  return ChatThreadView(
    thread: t,
    sessionState: t == null ? null : chat.sessionStateIn(t),
    connectorOperations: t == null ? null : chat.connectorOperationsIn(t),
    billingVerification: t == null ? null : chat.billingVerificationIn(t),
    todoPlan: t == null ? null : chat.todoPlanIn(t),
    reactionsFor: t == null ? null : (row) => chat.reactionsFor(t, row),
    onReactionDetails: t == null
        ? null
        : () => chat.reactionsIn(t)?.detailsOpened(),
    moaProgress: t == null ? const [] : chat.moaIn(t),
    onMoaDetails: chat.moaDetailsOpened,
    processOutputs: t == null ? null : chat.processOutputsIn(t),
    onProcessOutputDetails: chat.processOutputDetailsOpened,
    onSessionDetails: chat.sessionDetailsOpened,
    onReopenSession: t == null ? null : () => chat.reopenSession(t),
    chatController: chat.controllerFor(t),
    composerController: composerController,
    composerFocus: composerFocus,
    dictation: dictation,
    attachments: attachments,
    attachmentSource: attachmentSource,
    onAddAttachments: onAddAttachments,
    onRemoveAttachment: onRemoveAttachment,
    onSend: onSend,
    slashCommands: slashCommands,
    commandRunning: commandRunning || t != null && chat.queueBusy(t),
    queueView: protectedQueueView(chat, t),
    sendTarget: sendTarget,
    starterPrompts: starterPrompts,
    onPickStarter: onPickStarter ?? (_) {},
    greetingName: greetingName,
    header: header,
    latestReplyId: latestReply.id,
    turnActionStatus: latestReply.status,
    welcome: welcome,
    modelPill: recipientChip == null
        ? composerModelPill(chat)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: recipientChip),
              if (composerModelPill(chat) case final model?) ...[
                const SizedBox(width: 8),
                Flexible(child: model),
              ],
            ],
          ),
    botContext: t?.botContext,
    onRetry: t == null || chat.lastPromptText(t) == null
        ? null
        : () => chat.retry(t),
    onEdit: !editable || t == null || !chat.canEditLastPrompt(t)
        ? null
        : () => chat.editLastPrompt(t),
    onLoadOlder: t == null || !chat.hasOlder(t.id)
        ? null
        : () => chat.loadOlder(t.id),
    onAnswerApproval: t == null
        ? null
        : (id, choice) => chat.answerApproval(t, id, choice),
    onAnswerClarify: t == null
        ? null
        : (id, answers) => chat.answerClarify(t, id, answers),
    onSkipUnsupported: t == null
        ? null
        : (id, kind) => chat.skipUnsupported(t, id, kind),
    onAnswerVault: t == null
        ? null
        : (id, kind, {identifier = '', password = '', code = ''}) =>
              chat.answerVaultRequest(
                t,
                id,
                kind,
                identifier: identifier,
                password: password,
                code: code,
              ),
    onStop: t == null || chat.transport == null
        ? null
        : () => chat.stopReply(t),
    queued: t == null ? const [] : chat.queuedIn(t),
    onRemoveQueued: t == null ? null : (prompt) => chat.removeQueued(t, prompt),
    onSendQueued: t == null || !chat.queuePaused(t)
        ? null
        : () => chat.sendQueued(t),
  );
}
