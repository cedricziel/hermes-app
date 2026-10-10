import 'package:flutter/widgets.dart';

import '../models/widgets/composer_model_pill.dart';
import '../share/shared_item.dart';
import '../voice/dictation_controller.dart';
import 'attachments/attachment_source.dart';
import 'chat_controller.dart';
import 'chat_models.dart';
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

/// [ChatThreadView] for [thread] of [chat], with the chat's answers,
/// retries, paging and queue bound to [chat].
ChatThreadView boundChatThreadView({
  required ChatController chat,
  required ChatThread thread,
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
}) => ChatThreadView(
  thread: thread,
  chatController: chat.controllerFor(thread),
  composerController: composerController,
  composerFocus: composerFocus,
  dictation: dictation,
  attachments: attachments,
  attachmentSource: attachmentSource,
  onAddAttachments: onAddAttachments,
  onRemoveAttachment: onRemoveAttachment,
  onSend: onSend,
  onPickStarter: (_) {},
  latestReplyId: latestReply.id,
  turnActionStatus: latestReply.status,
  welcome: welcome,
  modelPill: composerModelPill(chat),
  botContext: thread.botContext,
  onRetry: chat.lastPromptText(thread) == null
      ? null
      : () => chat.retry(thread),
  onLoadOlder: chat.hasOlder(thread.id)
      ? () => chat.loadOlder(thread.id)
      : null,
  onAnswerApproval: (id, choice) => chat.answerApproval(thread, id, choice),
  onAnswerClarify: (id, answers) => chat.answerClarify(thread, id, answers),
  onSkipUnsupported: (id, kind) => chat.skipUnsupported(thread, id, kind),
  onAnswerVault: (id, kind, {identifier = '', password = '', code = ''}) =>
      chat.answerVaultRequest(
        thread,
        id,
        kind,
        identifier: identifier,
        password: password,
        code: code,
      ),
  onStop: chat.transport == null ? null : () => chat.stopReply(thread),
  queued: chat.queuedIn(thread),
  onRemoveQueued: (prompt) => chat.removeQueued(thread, prompt),
  onSendQueued: chat.queuePaused(thread) ? () => chat.sendQueued(thread) : null,
);
