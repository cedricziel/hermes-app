import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ChatAnimatedList, ChatMessage;
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';

import '../../theme/hermes_theme.dart';
import '../chat_message_kinds.dart';
import '../chat_models.dart'
    show
        ApprovalRequest,
        ChatAttachment,
        ClarifyRequest,
        ToolCall,
        UnsupportedKind,
        UnsupportedRequest;
import 'approval_card.dart';
import 'attachment_views.dart';
import 'clarify_card.dart';
import 'message_actions.dart';
import 'reasoning_block.dart';
import 'thinking_indicator.dart';
import 'tool_call_group.dart';
import 'unsupported_request_card.dart';
import 'welcome_view.dart';

/// Gutters around chat messages. The package's 8 px sat tighter than the top
/// bar and composer, and 2 px between the items of one reply ran the tool
/// cards into the text.
const double kChatGutter = 20;
const double kChatTurnGap = 20;
const double kChatItemGap = 8;

/// The `flutter_chat_ui` builders that give Hermes' message kinds and empty
/// state their assistant-ui look inside a `Chat`.
///
/// Text goes through [FlyerChatTextMessage] for both roles: it renders
/// markdown (headings, lists, tables, links, inline code, and fenced code
/// blocks with a language label and copy button) via `gpt_markdown`. Only the
/// surface differs — the user's turn is a rounded chip, the assistant's is
/// bare prose.
///
/// Widths are left to the caller: nothing here hard-codes a max width.
///
/// A finished reply gets an action bar. [latestReplyId] names the one reply
/// that can be asked again, and [onRetry] does it; while it is null nothing
/// can. [onPickPrompt] sends what the welcome view's starter prompts pick.
/// While [onLoadOlder] is set, scrolling to the top of the thread calls it.
Builders buildChatBuilders({
  required void Function(String prompt) onPickPrompt,
  String? greetingName,
  ValueListenable<String?>? latestReplyId,
  VoidCallback? onRetry,
  Future<void> Function()? onLoadOlder,
  Future<void> Function(String requestId, String choice)? onAnswerApproval,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onAnswerClarify,
  Future<void> Function(String requestId, UnsupportedKind kind)?
  onSkipUnsupported,
}) {
  return Builders(
    chatAnimatedListBuilder: onLoadOlder == null
        ? null
        : (context, itemBuilder) => ChatAnimatedList(
            itemBuilder: itemBuilder,
            onEndReached: onLoadOlder,
          ),
    textMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) =>
            _buildText(
              context,
              message,
              index,
              isSentByMe: isSentByMe,
              groupStatus: groupStatus,
              latestReplyId: latestReplyId,
              onRetry: onRetry,
            ),
    imageMessageBuilder: (
      context,
      message,
      index, {
      required isSentByMe,
      groupStatus,
    }) => _buildAttachment(message.metadata, image: true),
    fileMessageBuilder: (
      context,
      message,
      index, {
      required isSentByMe,
      groupStatus,
    }) => _buildAttachment(message.metadata, image: false),
    customMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) =>
            _buildCustom(
              context,
              message,
              index,
              isSentByMe: isSentByMe,
              groupStatus: groupStatus,
              onAnswerApproval: onAnswerApproval,
              onAnswerClarify: onAnswerClarify,
              onSkipUnsupported: onSkipUnsupported,
            ),
    chatMessageBuilder:
        (
          context,
          message,
          index,
          animation,
          child, {
          isRemoved,
          required isSentByMe,
          groupStatus,
        }) => ChatMessage(
          message: message,
          index: index,
          animation: animation,
          isRemoved: isRemoved,
          groupStatus: groupStatus,
          horizontalPadding: kChatGutter,
          verticalPadding: kChatTurnGap,
          verticalGroupedPadding: kChatItemGap,
          child: child,
        ),
    emptyChatListBuilder: (_) =>
        WelcomeView(greetingName: greetingName, onPick: onPickPrompt),
  );
}

Widget _buildText(
  BuildContext context,
  TextMessage message,
  int index, {
  required bool isSentByMe,
  MessageGroupStatus? groupStatus,
  ValueListenable<String?>? latestReplyId,
  VoidCallback? onRetry,
}) {
  final scheme = Theme.of(context).colorScheme;
  final failed = message.metadata?[kMetaError] == true;
  final style = TextStyle(
    color: failed ? scheme.error : scheme.onSurface,
    fontSize: 14.5,
    height: 1.5,
  );
  final bubble = FlyerChatTextMessage(
    message: message,
    index: index,
    showTime: false,
    showStatus: false,
    linksDecoration: TextDecoration.underline,
    sentTextStyle: style,
    receivedTextStyle: style,
    sentBackgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
    receivedBackgroundColor: Colors.transparent,
    borderRadius: BorderRadius.circular(isSentByMe ? kHermesRadius : 0),
    padding: isSentByMe
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : EdgeInsets.zero,
  );
  if (isSentByMe || message.metadata?[kMetaStreaming] == true) return bubble;

  Widget below(bool latest) => MessageActions(
    text: message.text,
    showCopy: !failed,
    onRetry: latest ? onRetry : null,
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      bubble,
      if (latestReplyId == null)
        below(false)
      else
        ValueListenableBuilder<String?>(
          valueListenable: latestReplyId,
          builder: (_, latest, _) => below(latest == message.id),
        ),
    ],
  );
}

Widget _buildAttachment(Map<String, dynamic>? metadata, {required bool image}) {
  final attachment = metadata?[kMetaAttachment];
  if (attachment is! ChatAttachment) return const SizedBox.shrink();
  return image
      ? AttachmentThumbnail(attachment: attachment)
      : AttachmentCard(attachment: attachment);
}

Widget _buildCustom(
  BuildContext context,
  CustomMessage message,
  int index, {
  required bool isSentByMe,
  MessageGroupStatus? groupStatus,
  Future<void> Function(String requestId, String choice)? onAnswerApproval,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onAnswerClarify,
  Future<void> Function(String requestId, UnsupportedKind kind)?
  onSkipUnsupported,
}) {
  final metadata = message.metadata;
  switch (metadata?[kMetaKind]) {
    case kKindToolGroup:
      return ToolCallGroup(calls: metadata![kMetaToolCalls] as List<ToolCall>);
    case kKindReasoning:
      return ReasoningBlock(
        text: metadata![kMetaReasoningText] as String,
        active: metadata[kMetaReasoningActive] == true,
      );
    case kKindThinking:
      return ThinkingIndicator(
        startedAt: metadata![kMetaThinkingStartedAt] as DateTime,
        activity: metadata[kMetaThinkingActivity] as String,
      );
    case kKindInputRequest:
      return switch (metadata![kMetaInputRequest]) {
        ApprovalRequest request => ApprovalCard(
          request: request,
          onAnswer: onAnswerApproval == null
              ? null
              : (choice) => onAnswerApproval(request.requestId, choice),
        ),
        ClarifyRequest request => ClarifyCard(
          request: request,
          onAnswer: onAnswerClarify == null
              ? null
              : (answers) => onAnswerClarify(request.requestId, answers),
        ),
        UnsupportedRequest request => UnsupportedRequestCard(
          request: request,
          onSkip: onSkipUnsupported == null
              ? null
              : () => onSkipUnsupported(request.requestId, request.kind),
        ),
        _ => const SizedBox.shrink(),
      };
    default:
      return const SizedBox.shrink();
  }
}
