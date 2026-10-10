import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../../notifications/notification_service.dart';
import '../../telemetry/breadcrumbs.dart';
import 'menu_bar_extra_link.dart';
import 'menu_bar_extra_model.dart';
import 'menu_bar_extra_settings.dart';
import 'menu_bar_menu.dart';
import 'menu_bar_tray.dart';

/// Keeps the menu bar item in step with the chats this app follows: its icon,
/// its menu, and what picking an entry does.
///
/// It reads only state the chat controller already holds, so opening the menu
/// sends no request. Telemetry carries fixed names, counts and choice names,
/// never a title, a command or an id.
class MenuBarExtra {
  MenuBarExtra({
    required this.tray,
    required this.settings,
    required this.link,
    required this.showMainWindow,
    required this.focusWindow,
    required this.confirmAlways,
    required this.quit,
    this.breadcrumbs = Breadcrumbs.none,
    this.events = _noEvents,
  }) {
    settings.addListener(_refresh);
    link.addListener(_relink);
    _subscriptions
      ..add(tray.selections.listen(_selected))
      ..add(tray.opened.listen((_) => _opened()));
    _relink();
  }

  final MenuBarTray tray;
  final MenuBarExtraSettings settings;
  final MenuBarExtraLink link;

  /// Brings the main window forward, also when it was closed.
  final Future<void> Function() showMainWindow;

  /// Brings the conversation window of a chat forward; false when the chat
  /// has none.
  final Future<bool> Function(String threadId, String? profile) focusWindow;

  /// Asks before an approval is answered "always"; true to go on.
  final Future<bool> Function() confirmAlways;
  final Future<void> Function() quit;
  final Breadcrumbs breadcrumbs;
  final AppEventLogger Function() events;

  static AppEventLogger _noEvents() => noopAppEventLogger;

  final _subscriptions = <StreamSubscription<void>>[];
  ChatController? _chat;
  var _model = MenuBarExtraModel.empty;
  Map<String, MenuBarAction> _actions = const {};
  bool? _visible;
  var _disposed = false;

  void _relink() {
    final chat = link.chat;
    if (!identical(chat, _chat)) {
      _chat?.removeListener(_refresh);
      _chat = chat?..addListener(_refresh);
    }
    _refresh();
  }

  void _refresh() {
    if (_disposed) return;
    final visible = settings.enabled;
    final model = MenuBarExtraModel.of(_chat);
    if (_visible == visible && model == _model) return;
    _visible = visible;
    _model = model;
    final menu = buildMenuBarMenu(model);
    _actions = menu.actions;
    unawaited(
      tray
          .update(visible: visible, state: model.state, items: menu.items)
          .catchError((Object error) {
            debugPrint('Could not update the menu bar item: $error');
          }),
    );
  }

  void _opened() => breadcrumbs('menubar.opened', {
    'replies': _model.replies.length,
    'approvals': _model.approvals,
  });

  Future<void> _selected(String key) async {
    final action = _actions[key];
    if (action == null) return;
    try {
      switch (action) {
        case OpenChatAction():
          breadcrumbs('menubar.action', {'kind': 'open_chat'});
          await _openChat(action.threadId, action.profile);
        case AnswerApprovalAction():
          breadcrumbs('menubar.action', {
            'kind': 'approve',
            'choice': action.choice,
          });
          await _answer(action.request, action.choice);
        case NewChatAction():
          breadcrumbs('menubar.action', {'kind': 'new_chat'});
          await showMainWindow();
          link.newChat();
        case ShowMainWindowAction():
          breadcrumbs('menubar.action', {'kind': 'show_main'});
          await showMainWindow();
        case QuitAction():
          breadcrumbs('menubar.action', {'kind': 'quit'});
          await quit();
      }
    } on Object catch (error) {
      debugPrint('The menu bar item could not act: $error');
    }
  }

  Future<void> _openChat(String threadId, String? profile) async {
    if (await focusWindow(threadId, profile)) return;
    await showMainWindow();
    link.openChat(NotificationTarget(threadId: threadId, profile: profile));
  }

  /// Answers through the chat controller, as the approval card does. A choice
  /// that did not go through leaves the chat to deal with it.
  Future<void> _answer(MenuBarRequest request, String choice) async {
    final chat = link.chat;
    final thread = chat?.threads
        .where((t) => t.id == request.threadId)
        .firstOrNull;
    if (chat == null || thread == null) return;
    if (choice == 'always') {
      await showMainWindow();
      if (!await confirmAlways()) return;
    }
    try {
      await chat.answerApproval(thread, request.requestId, choice);
    } on Object {
      // Handled like a rejection below.
    }
    final status = thread.messages
        .expand((m) => m.inputRequests)
        .where((r) => r.requestId == request.requestId)
        .map((r) => r.status)
        .firstOrNull;
    final accepted = status == InputRequestStatus.answered;
    try {
      events()('menubar.approval_answered', {
        'choice': choice,
        'accepted': accepted,
      });
    } on Object {
      // Telemetry must not take the answer down with it.
    }
    // A request the server withdrew shows as expired on its card; any other
    // answer that did not go through is left to the chat to explain.
    if (status == InputRequestStatus.pending) {
      await _openChat(request.threadId, request.profile);
    }
  }

  void dispose() {
    _disposed = true;
    settings.removeListener(_refresh);
    link.removeListener(_relink);
    _chat?.removeListener(_refresh);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(
      tray
          .update(visible: false, state: MenuBarIconState.idle, items: const [])
          .catchError((Object _) {}),
    );
  }
}
