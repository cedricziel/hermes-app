import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../app_lock/app_lock_controller.dart';
import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../../chat/widgets/approval_card.dart';
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
/// sends no request. While the app is locked the menu shows counts and an
/// Unlock entry, never a title or a command, and answers nothing. Telemetry
/// carries fixed names, counts and choice names, never a title, a command or
/// an id.
class MenuBarExtra {
  MenuBarExtra({
    required this.tray,
    required this.settings,
    required this.link,
    required this.showMainWindow,
    required this.focusWindow,
    required this.confirmAlways,
    required this.quit,
    this.lock,
    this.breadcrumbs = Breadcrumbs.none,
    this.events = _noEvents,
    this.refreshInterval = const Duration(milliseconds: 150),
  }) {
    settings.addListener(_apply);
    link.addListener(_relink);
    lock?.addListener(_apply);
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

  /// The App Lock, if the app has one.
  final AppLockController? lock;
  final Breadcrumbs breadcrumbs;
  final AppEventLogger Function() events;

  /// The shortest time between two menus built from chat changes, which come
  /// with every streamed word. Zero builds at once.
  final Duration refreshInterval;

  static AppEventLogger _noEvents() => noopAppEventLogger;

  final _subscriptions = <StreamSubscription<void>>[];
  ChatController? _chat;
  var _model = MenuBarExtraModel.empty;
  var _locked = false;
  var _shownInFlight = const <String>[];
  Map<String, MenuBarAction> _actions = const {};

  /// Whether the runner has the item on screen.
  var _shown = false;
  var _disposed = false;

  /// The requests being answered, by [MenuBarRequest.key].
  final _inFlight = <String>{};
  Timer? _throttle;
  var _changedMeanwhile = false;

  void _relink() {
    final chat = link.chat;
    if (!identical(chat, _chat)) {
      _chat?.removeListener(_onChatChanged);
      _chat = chat?..addListener(_onChatChanged);
    }
    _apply();
  }

  /// A chat change is applied now unless one was applied less than
  /// [refreshInterval] ago, in which case the latest state follows when the
  /// interval is over.
  void _onChatChanged() {
    if (_disposed) return;
    if (refreshInterval == Duration.zero) return _apply();
    if (_throttle?.isActive ?? false) {
      _changedMeanwhile = true;
      return;
    }
    _apply();
    _throttle = Timer(refreshInterval, _throttled);
  }

  void _throttled() {
    if (_disposed || !_changedMeanwhile) return;
    _changedMeanwhile = false;
    _apply();
    _throttle = Timer(refreshInterval, _throttled);
  }

  void _apply() {
    if (_disposed) return;
    final visible = settings.loaded && settings.enabled;
    if (!visible) {
      if (_shown) _send(visible: false, model: MenuBarExtraModel.empty);
      return;
    }
    final model = MenuBarExtraModel.of(_chat);
    final locked = lock?.covered ?? false;
    final inFlight = _inFlight.toList()..sort();
    if (_shown &&
        model == _model &&
        locked == _locked &&
        listEquals(inFlight, _shownInFlight)) {
      return;
    }
    // Only the move into the lock cannot wait for an open menu to close.
    final urgent = locked && !_locked;
    _locked = locked;
    _shownInFlight = inFlight;
    _send(visible: true, model: model, urgent: urgent);
  }

  void _send({
    required bool visible,
    required MenuBarExtraModel model,
    bool urgent = false,
  }) {
    _shown = visible;
    _model = model;
    final menu = visible
        ? buildMenuBarMenu(model, locked: _locked, inFlight: _inFlight)
        : const MenuBarMenu([], {});
    _actions = menu.actions;
    unawaited(
      tray
          .update(
            visible: visible,
            state: visible ? model.state : MenuBarIconState.idle,
            items: menu.items,
            urgent: urgent,
          )
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
    if (action == null) {
      // The menu changed under the pick: it does nothing rather than
      // something else.
      breadcrumbs('menubar.stale_pick');
      return;
    }
    try {
      switch (action) {
        case OpenChatAction():
          breadcrumbs('menubar.action', {'kind': 'open_chat'});
          await _openChat(action.threadId, action.profile);
        case AnswerApprovalAction():
          if (_inFlight.contains(action.request.key)) {
            breadcrumbs('menubar.stale_pick');
            return;
          }
          breadcrumbs('menubar.action', {
            'kind': 'approve',
            'choice': _fixedChoice(action.choice),
          });
          await _answer(action.request, action.choice);
        case NewChatAction():
          breadcrumbs('menubar.action', {'kind': 'new_chat'});
          await showMainWindow();
          link.newChat();
        case ShowMainWindowAction():
          breadcrumbs('menubar.action', {'kind': 'show_main'});
          await showMainWindow();
        case UnlockAction():
          breadcrumbs('menubar.action', {'kind': 'unlock'});
          await showMainWindow();
          await lock?.unlock();
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

  /// The request [requestId] in [thread], if it still waits for [choice].
  ApprovalRequest? _awaiting(
    ChatThread thread,
    String requestId,
    String choice,
  ) {
    for (final message in thread.messages) {
      for (final request in message.inputRequests) {
        if (request.requestId == requestId &&
            request is ApprovalRequest &&
            request.status == InputRequestStatus.pending &&
            offeredApprovalChoices(request).contains(choice)) {
          return request;
        }
      }
    }
    return null;
  }

  /// Answers through the chat controller, as the approval card does, once.
  /// The request counts as in flight from the pick until the answer settles,
  /// also while the "always" question is open. A choice that did not go
  /// through leaves the chat to deal with it.
  Future<void> _answer(MenuBarRequest request, String choice) async {
    _inFlight.add(request.key);
    _apply();
    try {
      final chat = link.chat;
      final thread = chat?.threads
          .where((t) => t.id == request.threadId)
          .firstOrNull;
      if (chat == null || thread == null) {
        // The chat is gone from this profile's list; the chat screen can
        // fetch it.
        await _openChat(request.threadId, request.profile);
        return;
      }
      if (_awaiting(thread, request.requestId, choice) == null) return;
      if (choice == 'always') {
        await showMainWindow();
        final confirmed = await confirmAlways();
        // Answered elsewhere meanwhile, or the app locked behind the
        // question.
        if (!confirmed ||
            (lock?.covered ?? false) ||
            _awaiting(thread, request.requestId, choice) == null) {
          return;
        }
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
      try {
        events()('menubar.approval_answered', {
          'choice': _fixedChoice(choice),
          'accepted': status == InputRequestStatus.answered,
        });
      } on Object {
        // Telemetry must not take the answer down with it.
      }
      // A request the server withdrew shows as expired on its card; any
      // other answer that did not go through is left to the chat to explain.
      if (status == InputRequestStatus.pending) {
        await _openChat(request.threadId, request.profile);
      }
    } finally {
      _inFlight.remove(request.key);
      _apply();
    }
  }

  /// [choice] if it is one of the four Hermes defines, else `other`: the
  /// agent can send any string.
  static String _fixedChoice(String choice) =>
      approvalChoiceLabels.containsKey(choice) ? choice : 'other';

  void dispose() {
    if (_disposed) return;
    final wasShown = _shown;
    _disposed = true;
    _throttle?.cancel();
    settings.removeListener(_apply);
    link.removeListener(_relink);
    lock?.removeListener(_apply);
    _chat?.removeListener(_onChatChanged);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (wasShown) {
      unawaited(
        tray
            .update(
              visible: false,
              state: MenuBarIconState.idle,
              items: const [],
            )
            .catchError((Object _) {}),
      );
    }
  }
}
