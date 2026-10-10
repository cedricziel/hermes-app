import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../chat/chat_models.dart';
import '../../telemetry/breadcrumbs.dart';
import 'dock_menu_bridge.dart';

/// How a chat picked in the Dock menu was opened.
enum DockOpenResult { inWindow, inMain, unavailable, failed }

typedef DockOpen = Future<DockOpenResult> Function(String id, String profile);

const _recentCount = 5;
const _titleLength = 40;
const _untitled = 'Untitled chat';

/// What the Dock menu shows, and what its choices do.
///
/// AppKit asks for the menu synchronously, so the runner keeps a copy that
/// this pushes whenever it changes. The copy holds chat titles only while the
/// connection is ready and the app unlocked: [configure] drops them on
/// sign-out, a change of server and an app lock, and the chat screen drops
/// them when it goes away ([clearChats]).
///
/// The chat screen supplies the recent chats ([setChats]) and what a choice
/// does ([bind]); this decides when a choice may run. A New Chat picked
/// while the app is locked waits for the unlock and is dropped if the unlock
/// fails or the state changes first.
class DockMenuController extends ChangeNotifier {
  DockMenuController({
    required this.bridge,
    required this._unlock,
    this.breadcrumbs = Breadcrumbs.none,
    this.events = noopAppEventLogger,
  }) {
    _actions = bridge.actions.listen(_onAction);
  }

  final DockMenuBridge bridge;
  final Future<bool> Function() _unlock;
  final Breadcrumbs breadcrumbs;
  final AppEventLogger events;

  late final StreamSubscription<DockMenuAction> _actions;
  DockMenuState _state = DockMenuState.off;
  List<DockChat> _chats = const [];
  ({DockMenuState state, List<DockChat> chats})? _pushed;
  DockOpen? _open;
  VoidCallback? _newChat;
  Object? _pending;
  bool _disposed = false;

  DockMenuState get state => _state;

  /// Takes the chat screen's way of opening a chat and starting a new one.
  void bind({DockOpen? open, VoidCallback? newChat}) {
    _open = open;
    _newChat = newChat;
  }

  /// Moves to [next]. Leaving [DockMenuState.ready] drops the chats, and
  /// signing out or locking again drops a New Chat that waits to run.
  void configure(DockMenuState next) {
    if (_disposed) return;
    final changed = next != _state;
    _state = next;
    if (next != DockMenuState.ready) _chats = const [];
    if (_pending != null &&
        (next == DockMenuState.off ||
            (changed && next == DockMenuState.locked))) {
      _endPending('cancelled');
    }
    _push();
    if (changed) notifyListeners();
  }

  /// Offers the newest saved chats of [profile] from [threads]. Does nothing
  /// until the state is ready; streaming that only moves a chat's time does
  /// not push again.
  void setChats(Iterable<ChatThread> threads, String? profile) {
    if (_disposed || _state != DockMenuState.ready) return;
    _chats = profile == null ? const [] : recentChats(threads, profile);
    _push();
  }

  /// Forgets the chats, as when the chat screen goes away.
  void clearChats() {
    if (_disposed || _chats.isEmpty) return;
    _chats = const [];
    _push();
  }

  /// The newest saved chats of [profile] that a user created: hidden Bot
  /// Chat registries and local drafts are left out, pinning is ignored.
  @visibleForTesting
  static List<DockChat> recentChats(
    Iterable<ChatThread> threads,
    String profile,
  ) {
    final chats = [
      for (final thread in threads)
        if (thread.remote && !thread.isCanonicalBotChat) thread,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [
      for (final thread in chats.take(_recentCount))
        (id: thread.id, profile: profile, title: _menuTitle(thread.title)),
    ];
  }

  static String _menuTitle(String title) {
    final plain = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (plain.isEmpty) return _untitled;
    final characters = plain.characters;
    if (characters.length <= _titleLength) return plain;
    return '${characters.take(_titleLength - 1)}…';
  }

  void _push() {
    final next = (state: _state, chats: _chats);
    final last = _pushed;
    if (last != null &&
        last.state == next.state &&
        listEquals(last.chats, next.chats)) {
      return;
    }
    _pushed = next;
    unawaited(bridge.update(next.state, next.chats));
  }

  void _onAction(DockMenuAction action) {
    switch (action) {
      case DockNewChat():
        unawaited(_onNewChat());
      case DockOpenChat(:final id, :final profile):
        unawaited(_onOpenChat(id, profile));
    }
  }

  Future<void> _onOpenChat(String id, String profile) async {
    final open = _open;
    if (_state != DockMenuState.ready || open == null) return;
    DockOpenResult result;
    try {
      result = await open(id, profile);
    } on Object {
      result = DockOpenResult.failed;
    }
    breadcrumbs('dock.menu.action', {
      'action': 'open_chat',
      'window': result == DockOpenResult.inWindow,
      'deferred': false,
    });
    if (result == DockOpenResult.unavailable ||
        result == DockOpenResult.failed) {
      events('dock.menu.open_failed', {
        'reason': result == DockOpenResult.unavailable
            ? 'unavailable'
            : 'network',
      });
    }
  }

  Future<void> _onNewChat() async {
    final run = _newChat;
    if (run == null) return;
    switch (_state) {
      case DockMenuState.off:
        return;
      case DockMenuState.ready:
        _recordNewChat(deferred: false);
        run();
      case DockMenuState.locked:
        if (_pending != null) _endPending('cancelled');
        final ticket = _pending = Object();
        bool unlocked;
        try {
          unlocked = await _unlock();
        } on Object {
          unlocked = false;
        }
        // Something else ended this one: a relock, a sign-out, a newer pick.
        if (_disposed || _pending != ticket) return;
        if (!unlocked || _state != DockMenuState.ready) {
          return _endPending('cancelled');
        }
        _endPending('completed');
        _recordNewChat(deferred: true);
        run();
    }
  }

  void _recordNewChat({required bool deferred}) {
    breadcrumbs('dock.menu.action', {
      'action': 'new_chat',
      'window': false,
      'deferred': deferred,
    });
  }

  void _endPending(String outcome) {
    _pending = null;
    breadcrumbs('dock.menu.deferred', {'outcome': outcome});
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_actions.cancel());
    super.dispose();
  }
}
