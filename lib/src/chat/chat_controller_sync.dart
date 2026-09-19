import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController, Message;

/// Rewrites one chat message's flyer messages in [controller], from [before]
/// to [after] (both from `chatMessageToFlyer`, before and after a change).
///
/// Messages that keep their id are updated in place, gone ones are removed
/// and new ones inserted, all within the slot [before] occupied, so a reply
/// that changes while later messages were added stays beside its prompt.
void syncMessage(
  InMemoryChatController controller,
  List<Message> before,
  List<Message> after,
) {
  final held = {for (final m in before) m.id};
  final kept = {for (final m in after) m.id};
  final slot = before.isEmpty
      ? -1
      : controller.messages.indexWhere((m) => m.id == before.first.id);
  for (final m in before) {
    if (!kept.contains(m.id)) controller.removeMessage(m);
  }
  for (final (i, message) in after.indexed) {
    if (held.contains(message.id)) {
      controller.updateMessage(message, message);
    } else {
      controller.insertMessage(message, index: slot < 0 ? null : slot + i);
    }
  }
}
