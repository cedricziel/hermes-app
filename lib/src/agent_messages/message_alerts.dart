import '../notifications/attention_policy.dart';
import '../notifications/request_notifications.dart';
import '../schedules/schedule_alerts.dart' show kSummaryAbove;
import 'find_messages.dart';

const kMessageFallbackTitle = 'Message from Hermes';

/// The notifications [found] deserves. [texts] holds the text of each
/// message (by [FoundMessage.key]) that could be read in time; the body is
/// "New message" for one that is missing or empty, and for all of them while
/// [appLock] is on, which also hides the title, since a delivery's title is
/// made from its text. A message of a profile other than [shownProfile] says
/// which. Until App Lock's setting has loaded a caller passes
/// `appLock: true`, and it maps a [listDeliveries] that threw or timed out
/// to a null listing for [findMessages].
List<AttentionNotification> messageAlertsFor(
  MessagesFound found,
  Map<({String profile, String id}), String> texts, {
  required String? shownProfile,
  required bool appLock,
}) {
  final messages = found.messages;
  if (messages.length > kSummaryAbove) {
    return [
      AttentionNotification(
        threadId: '',
        title: 'Hermes',
        body: found.capped
            ? '${messages.length} or more new messages'
            : '${messages.length} new messages',
        isMessage: true,
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
        isMessage: true,
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
