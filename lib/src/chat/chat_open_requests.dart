import 'package:flutter/foundation.dart';

import '../notifications/notification_service.dart';
import '../bot_mode/bot_chat_context.dart';

class ChatOpenRequest {
  const ChatOpenRequest(this.target, this.bot);
  final NotificationTarget target;
  final BotChatContext? bot;
}

/// How another destination asks the chat to open a session, such as one run
/// of a scheduled task. The chat listens, takes the request and opens it; a
/// request made before the chat is listening waits for it.
class ChatOpenRequests extends ChangeNotifier {
  ChatOpenRequest? _pending;

  bool get hasPending => _pending != null;

  void request(NotificationTarget target, {BotChatContext? bot}) {
    _pending = ChatOpenRequest(target, bot);
    notifyListeners();
  }

  ChatOpenRequest? takeRequest() {
    final target = _pending;
    _pending = null;
    return target;
  }

  NotificationTarget? take() => takeRequest()?.target;
}
