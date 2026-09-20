import 'package:flutter/foundation.dart';

import '../notifications/notification_service.dart';

/// How another destination asks the chat to open a session, such as one run
/// of a scheduled task. The chat listens, takes the request and opens it; a
/// request made before the chat is listening waits for it.
class ChatOpenRequests extends ChangeNotifier {
  NotificationTarget? _pending;

  bool get hasPending => _pending != null;

  void request(NotificationTarget target) {
    _pending = target;
    notifyListeners();
  }

  NotificationTarget? take() {
    final target = _pending;
    _pending = null;
    return target;
  }
}
