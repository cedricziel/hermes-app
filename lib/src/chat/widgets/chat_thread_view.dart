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
    this.sendTarget,
    this.starterPrompts,
    required this.onPickStarter,
    required this.latestReplyId,
    this.turnActionStatus,
    this.modelPill,
    this.header,
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
            sendTarget: sendTarget,
          ),
          emptyChatListBuilder: welcome ? null : (_) => const SizedBox.shrink(),
        );

    return Column(
      children: [
        if (header case final header?) ...[
          header,
          if (platformChromeOf(context) != PlatformChrome.macos)
            const Divider(height: 1),
        ],
        if (botContext case final bot?) BotChatBanner(context: bot),
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
                      builders: builders,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
