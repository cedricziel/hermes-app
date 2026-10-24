import '../notifications/attention_policy.dart';
import '../notifications/request_notifications.dart';
import 'agent_delivery.dart';
import 'find_messages.dart';

const kMessageFallbackTitle = 'Message from Hermes';

/// More messages than this in one look are announced as one notification.
const kMessageSummaryAbove = 5;

/// The notifications [found] deserves. [texts] holds the text of each
/// message (by [FoundMessage.key]) that could be read in time; the body is
/// "New message" for one that is missing or empty, and for all of them while
/// [appLock] is on, which also hides the title, since a delivery's title is
/// made from its text. A message of a profile other than [shownProfile] says
/// which.
List<AttentionNotification> messageAlertsFor(
  MessagesFound found,
  Map<({String profile, String id}), String> texts, {
  required String? shownProfile,
  required bool appLock,
}) {
  final messages = found.messages;
  if (messages.length > kMessageSummaryAbove) {
    return [
      AttentionNotification(
        threadId: '',
        title: 'Hermes',
        body: found.capped
            ? '${kDeliveryPages * kDeliveryPageSize} or more new messages'
            : '${messages.length} new messages',
        category: messageCategory,
      ),
    ];
  }
  return [
    for (final message in messages)
      AttentionNotification(
        threadId: message.delivery.id,
        profile: message.profile,
        title: appLock
            ? kMessageFallbackTitle
            : _title(message, shownProfile: shownProfile),
        body: appLock ? kNewMessageBody : _body(texts[message.key]),
        bodyIsPlainText: true,
        category: messageCategory,
      ),
  ];
}

String _title(FoundMessage message, {required String? shownProfile}) {
  final title = message.delivery.title?.trim();
  if (title == null || title.isEmpty) return kMessageFallbackTitle;
  return shownProfile != null && message.profile != shownProfile
      ? '$title (${message.profile})'
      : title;
}

String _body(String? text) {
  final preview = text == null ? '' : replyPreview(text);
  return preview.isEmpty ? kNewMessageBody : preview;
}
