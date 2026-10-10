import 'package:flutter/foundation.dart';

import '../notifications/notification_service.dart';
import '../bot_mode/bot_chat_context.dart';

/// What another destination asks the chat to show.
sealed class ChatOpenRequest {
  const ChatOpenRequest();
}

/// A session, such as one run of a scheduled task. A [prompt] is put in its
/// composer once it is open and is never sent.
class OpenSessionRequest extends ChatOpenRequest {
  const OpenSessionRequest(this.target, this.bot, {this.prompt});
  final NotificationTarget target;
  final BotChatContext? bot;
  final String? prompt;
}

/// A new chat, in [profile] when given. A [prompt] is put in its composer and
/// never sent; [dictate] starts the microphone when the profile offers it.
class NewChatRequest extends ChatOpenRequest {
  const NewChatRequest({this.profile, this.prompt, this.dictate = false});
  final String? profile;
  final String? prompt;
  final bool dictate;
}

/// The chat holding the open request that was raised first, or the chat list
/// when no loaded chat holds one.
class OldestPendingRequest extends ChatOpenRequest {
  const OldestPendingRequest();
}

/// How another destination asks the chat to show something, such as one run
/// of a scheduled task. The chat listens, takes the request and acts on it; a
/// request made before the chat is listening waits for it.
class ChatOpenRequests extends ChangeNotifier {
  ChatOpenRequest? _pending;

  bool get hasPending => _pending != null;

  void request(
    NotificationTarget target, {
    BotChatContext? bot,
    String? prompt,
  }) => _ask(OpenSessionRequest(target, bot, prompt: prompt));

  void requestNew({String? profile, String? prompt, bool dictate = false}) =>
      _ask(NewChatRequest(profile: profile, prompt: prompt, dictate: dictate));

  void requestOldestPending() => _ask(const OldestPendingRequest());

  void _ask(ChatOpenRequest request) {
    _pending = request;
    notifyListeners();
  }

  ChatOpenRequest? takeRequest() {
    final request = _pending;
    _pending = null;
    return request;
  }
}
