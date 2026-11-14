import 'package:flutter/widgets.dart';

import '../chat_controller.dart';
import '../chat_models.dart';

/// The controller a page pushed inside the Activity panel shows, looked up
/// in the chat and listened to with it. The page goes back to the panel when
/// the controller goes (a profile switch, sign-out, a chat that is gone) or
/// App Lock covers the app, since a locked page must not show its content.
mixin ActivityPageBinding<W extends StatefulWidget, C extends ChangeNotifier>
    on State<W> {
  ChatController get chat;

  /// The chat this page was opened for.
  ChatThread get thread;

  /// [thread] as the chat holds it now: the same chat after a re-read of the
  /// thread list may be a new object with the same id. Null once it is gone.
  ChatThread? get currentThread {
    final threads = chat.threads;
    if (threads.contains(thread)) return thread;
    for (final candidate in threads) {
      if (candidate.id == thread.id) return candidate;
    }
    return null;
  }

  /// The controller for this page's chat, or null when it has none now.
  C? lookUpController();
  bool lockedOf(C controller);

  C? _controller;
  Listenable? _listening;
  var _leaving = false;

  /// Null only once the page is leaving.
  C? get controller => _controller;

  /// Call from [initState].
  void bindController() {
    _controller = lookUpController();
    final listening = _listening = Listenable.merge([chat, ?_controller]);
    listening.addListener(_changed);
    final controller = _controller;
    if (controller == null || lockedOf(controller)) leaveToPanel();
  }

  /// Call from [dispose].
  void unbindController() {
    _listening?.removeListener(_changed);
    _listening = null;
  }

  void _changed() {
    if (!mounted || _leaving) return;
    final current = lookUpController();
    if (current == null || !identical(current, _controller)) {
      leaveToPanel();
      return;
    }
    if (lockedOf(current)) {
      leaveToPanel();
      return;
    }
    setState(() {});
  }

  /// Back to the panel, after the frame: a notification may arrive while
  /// another widget builds.
  void leaveToPanel() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}
