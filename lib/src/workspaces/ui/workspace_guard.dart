import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';

/// Tells a picker, a details sheet or a confirmation when it must close:
/// the folders were dropped (sign-out, Change Server, App Lock), the chat's
/// profile changed, the session ended, or the chat the sheet is about is no
/// longer the open one.
///
/// A surface listens to [closed] and pops itself; a confirmation passes it as
/// `dismissWhen`. One guard serves everything one gesture opens, and the
/// opener disposes it when the last of them is gone.
class WorkspaceGuard {
  WorkspaceGuard(this.chat, {ChatThread? thread})
    : _threadId = thread?.id,
      _epoch = chat.workspaceEpoch,
      _profile = chat.profile {
    chat.addListener(_check);
  }

  final ChatController chat;
  final String? _threadId;
  final int _epoch;
  final String? _profile;
  final _closed = ValueNotifier<bool>(false);
  bool _disposed = false;

  /// True once whatever it guards must go.
  ValueListenable<bool> get closed => _closed;

  /// The chat's profile when the guard was made.
  String? get profile => _profile;

  void _check() {
    if (_closed.value || _disposed) return;
    // Sign-out, Change Server, App Lock and a profile switch all bump the
    // epoch; no separate "session ended" check lives here.
    if (chat.disposed ||
        chat.workspaceEpoch != _epoch ||
        chat.profile != _profile ||
        (_threadId != null && chat.selectedId != _threadId)) {
      _closed.value = true;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    chat.removeListener(_check);
    _closed.dispose();
  }
}

/// Removes the route that [context] belongs to, wherever it sits in the
/// stack. `Navigator.pop` would take the top route, which may be a
/// confirmation or a picker opened over this one.
void closeOwnRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  route.navigator?.removeRoute(route);
}
