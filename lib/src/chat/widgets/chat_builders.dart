import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';

import '../../theme/hermes_theme.dart';
import '../chat_message_kinds.dart';
import '../chat_models.dart'
    show
        ApprovalRequest,
        ChatAttachment,
        ClarifyRequest,
        ToolCall,
        ToolCallStatus,
        UnsupportedKind,
        UnsupportedRequest;
import 'approval_card.dart';
import 'attachment_views.dart';
import 'clarify_card.dart';
import 'follow_up_chips.dart';
import 'message_actions.dart';
import 'reasoning_block.dart';
import 'thinking_indicator.dart';
import 'tool_call_card.dart';
import 'unsupported_request_card.dart';
import 'welcome_view.dart';

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
/// can. That reply also gets follow-up chips, which send through
/// [onPickPrompt].
Builders buildChatBuilders({
  required void Function(String prompt) onPickPrompt,
  String? greetingName,
  ValueListenable<String?>? latestReplyId,
  VoidCallback? onRetry,
  Future<void> Function(String requestId, String choice)? onAnswerApproval,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onAnswerClarify,
  Future<void> Function(String requestId, UnsupportedKind kind)?
  onSkipUnsupported,
}) {
  return Builders(
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
              onFollowUp: onPickPrompt,
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
  void Function(String prompt)? onFollowUp,
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

  Widget below(bool latest) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MessageActions(
        text: message.text,
        showCopy: !failed,
        onRetry: latest ? onRetry : null,
      ),
      if (latest && !failed && onFollowUp != null)
        FollowUpChips(onPick: onFollowUp),
    ],
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
    case kKindToolCall:
      return ToolCallCard(
        call: ToolCall(
          name: metadata![kMetaToolName] as String,
          summary: metadata[kMetaToolSummary] as String,
          status: ToolCallStatus.values.byName(
            metadata[kMetaToolStatus] as String,
          ),
          result: metadata[kMetaToolResult] as String? ?? '',
        ),
      );
    case kKindReasoning:
      return ReasoningBlock(
        text: metadata![kMetaReasoningText] as String,
        active: metadata[kMetaReasoningActive] == true,
      );
    case kKindThinking:
      return const ThinkingIndicator();
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
