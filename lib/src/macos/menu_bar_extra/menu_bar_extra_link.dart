import 'package:flutter/foundation.dart';

import '../../chat/chat_controller.dart';
import '../../notifications/notification_service.dart';

/// Joins the menu bar item, which lives above the shell, to the chat screen
/// that owns the chat controller. The chat screen connects while it is on
/// screen, so a signed-out app has no chat here and the menu offers only its
/// fixed entries.
class MenuBarExtraLink extends ChangeNotifier {
  ChatController? _chat;
  void Function(NotificationTarget target)? _openChat;
  VoidCallback? _newChat;

  /// The chat whose replies and requests the menu lists; null while signed
  /// out.
  ChatController? get chat => _chat;

  void connect({
    required ChatController chat,
    required void Function(NotificationTarget target) openChat,
    required VoidCallback newChat,
  }) {
    _chat = chat;
    _openChat = openChat;
    _newChat = newChat;
    notifyListeners();
  }

  /// Forgets [chat] if it is still the connected one.
  void disconnect(ChatController chat) {
    if (_chat != chat) return;
    _chat = null;
    _openChat = null;
    _newChat = null;
    notifyListeners();
  }

  /// Shows the chat of [target] in the main window's chat screen.
  void openChat(NotificationTarget target) => _openChat?.call(target);

  void newChat() => _newChat?.call();
}
