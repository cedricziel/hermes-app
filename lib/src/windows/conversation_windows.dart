import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/widgets/thread_actions_menu.dart';

import 'conversation_window_args.dart';
import 'window_auth_interceptor.dart';

/// A chat on a profile; a session id is only unique within one.
typedef ConversationRef = ({String threadId, String? profile});

/// Answers a call a conversation window makes to the main window.
typedef ConversationWindowCallHandler = Future<Object?> Function(
  String method,
  Map<String, Object?> args,
);

/// The native side of conversation windows, as the main window sees it.
abstract interface class ConversationWindowHost {
  /// Opens a window for [args] and returns its id. The window shows itself
  /// once it has set up its frame.
  Future<String> create(ConversationWindowArgs args);

  /// Brings the window to the front; throws for a window that is gone.
  Future<void> focus(String windowId);

  /// Sends a thread action, by name, to the window's own engine.
  Future<void> command(String windowId, String command);

  /// Closes the window natively, whether or not its engine is listening.
  Future<void> close(String windowId);

  /// Closes every conversation window natively.
  Future<void> closeAll();

  /// Brings the main window back, also after it was closed.
  Future<void> showMain();

  /// The ids of every window still open, each time one opens or closes.
  Stream<Set<String>> get liveWindows;

  /// Fires each time the main window becomes the key window.
  Stream<void> get mainFocused;

  void listen(ConversationWindowCallHandler handler);
}

/// One open conversation window.
class ConversationWindowEntry {
  const ConversationWindowEntry(
    this.windowId,
    this.args, {
    this.pinned = false,
  });

  final String windowId;
  final ConversationWindowArgs args;

  /// Whether the window's chat is pinned, as the window last reported.
  final bool pinned;
}

/// Keeps the open windows' arguments for the next launch.
class ConversationWindowStore {
  ConversationWindowStore(this._prefs);

  final SharedPreferencesAsync _prefs;
  static const _key = 'conversation_windows';

  Future<List<ConversationWindowArgs>> load() async {
    try {
      final saved = await _prefs.getString(_key);
      if (saved == null) return const [];
      final rows = jsonDecode(saved);
      if (rows is! List) return const [];
      return [...rows.map(ConversationWindowArgs.fromJson).nonNulls];
    } on Object {
      return const [];
    }
  }

  Future<void> save(Iterable<ConversationWindowArgs> windows) async {
    try {
      await _prefs.setString(
        _key,
        jsonEncode([for (final w in windows) w.toJson()]),
      );
    } on Object catch (error) {
      debugPrint('Could not save the conversation windows: $error');
    }
  }
}

/// The conversation windows of the main window (macOS): which are open,
/// which is key, the calls they make to the main window, and the list that
/// is opened again on the next launch.
class ConversationWindows extends ChangeNotifier {
  ConversationWindows({
    required this._host,
    required this._store,
    required this._connection,
    required this._headers,
  }) {
    _host.listen(_handle);
    _subscriptions
      ..add(_host.liveWindows.listen(_retain))
      ..add(
        _host.mainFocused.listen((_) {
          _setKey(null);
          _mainFocused.add(null);
        }),
      );
  }

  final ConversationWindowHost _host;
  final ConversationWindowStore _store;
  final ({String baseUrl, bool authRequired})? Function() _connection;
  final WindowAuthHeaders _headers;
  final _subscriptions = <StreamSubscription<void>>[];
  final _mainFocused = StreamController<void>.broadcast();
  final _showInMain = StreamController<ConversationRef>.broadcast();

  final _windows = <ConversationWindowEntry>[];
  List<ConversationWindowEntry> get windows => List.unmodifiable(_windows);

  /// The conversation window that is key; null while the main window is.
  String? get keyWindowId => _keyWindowId;
  String? _keyWindowId;

  final _touched = <ConversationRef>{};

  /// The conversation window that is key, or null while the main window is.
  ConversationWindowEntry? get keyWindow {
    for (final window in _windows) {
      if (window.windowId == _keyWindowId) return window;
    }
    return null;
  }

  /// The open window of [threadId] on [profile], if there is one.
  ConversationWindowEntry? windowFor(String threadId, String? profile) {
    for (final window in _windows) {
      if (window.args.shows(threadId, profile)) return window;
    }
    return null;
  }

  /// The chats opened in a window this session, which the main window
  /// reloads when it becomes key again.
  List<ConversationRef> get touched => [..._touched];

  /// Fires each time the main window becomes key.
  Stream<void> get mainFocused => _mainFocused.stream;

  /// The chats a window asked the main window to select ("Show in Main
  /// Window").
  Stream<ConversationRef> get showInMainRequests => _showInMain.stream;

  bool _restored = false;

  /// Windows being created, whose ids are not known yet. A new window can ask
  /// for headers before its creation has returned.
  final _creating = <Future<void>>{};

  /// Bumped by [closeAll], so windows a restore is still opening for the old
  /// session are closed again.
  int _generation = 0;

  /// Opens [threadId] of [profile] in a window of its own, or brings its
  /// window to the front when it already has one.
  Future<void> open(
    String threadId, {
    required String? profile,
    required String title,
  }) async {
    if (windowFor(threadId, profile) case final window?) {
      if (await focus(window.windowId)) return;
    }
    final connection = _connection();
    if (connection == null) return;
    await _create(
      ConversationWindowArgs(
        threadId: threadId,
        profile: profile,
        title: title,
        baseUrl: connection.baseUrl,
        authRequired: connection.authRequired,
      ),
    );
  }

  /// Opens the windows saved for the current server, once per launch.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final generation = _generation;
    final baseUrl = _connection()?.baseUrl;
    if (baseUrl == null) return;
    for (final args in await _store.load()) {
      if (args.baseUrl != baseUrl) continue;
      if (generation != _generation || !_isCurrent(args)) return;
      if (windowFor(args.threadId, args.profile) != null) continue;
      await _create(args);
    }
  }

  /// Whether [args] belong to the server the main window is signed in to.
  bool _isCurrent(ConversationWindowArgs args) =>
      _connection()?.baseUrl == args.baseUrl;

  Future<void> _create(ConversationWindowArgs args) async {
    final done = Completer<void>();
    _creating.add(done.future);
    try {
      await _createWindow(args);
    } finally {
      _creating.remove(done.future);
      done.complete();
    }
  }

  Future<void> _createWindow(ConversationWindowArgs args) async {
    final generation = _generation;
    final String windowId;
    try {
      windowId = await _host.create(args);
    } on Object catch (error) {
      debugPrint('Could not open a conversation window: $error');
      return;
    }
    if (generation != _generation || !_isCurrent(args)) {
      return _host.close(windowId);
    }
    _windows.add(ConversationWindowEntry(windowId, args));
    _touched.add((threadId: args.threadId, profile: args.profile));
    _changed();
  }

  /// Brings [windowId] to the front. A window that went away without the
  /// main window hearing of it is dropped, and false is returned.
  Future<bool> focus(String windowId) async {
    try {
      await _host.focus(windowId);
      return true;
    } on Object catch (error) {
      debugPrint('Conversation window $windowId is gone: $error');
      _drop(windowId);
      return false;
    }
  }

  void _drop(String windowId) {
    final before = _windows.length;
    _windows.removeWhere((w) => w.windowId == windowId);
    if (_keyWindowId == windowId) _setKey(null);
    if (_windows.length != before) _changed();
  }

  Future<void> showMainWindow() => _host.showMain();

  /// Closes the key conversation window; false when the main window is key.
  Future<bool> closeKeyWindow() async {
    final key = _keyWindowId;
    if (key == null) return false;
    await _host.close(key);
    return true;
  }

  /// Runs [action] (pin, rename, copy, archive, delete) on the chat of the
  /// key conversation window; false when the main window is key.
  Future<bool> runInKeyWindow(ThreadAction action) =>
      _commandKeyWindow(action.name);

  Future<bool> _commandKeyWindow(String command) async {
    final key = _keyWindowId;
    if (key == null) return false;
    await _host.command(key, command);
    return true;
  }

  /// Closes every window. A sign-out or another server also forgets them;
  /// with [forget] off (the session expired) they open again once the user
  /// is signed in.
  Future<void> closeAll({bool forget = true}) async {
    _generation++;
    _windows.clear();
    _setKey(null);
    if (forget) {
      _changed();
    } else {
      _restored = false;
      notifyListeners();
    }
    await _host.closeAll();
  }

  void _retain(Set<String> live) {
    final before = _windows.length;
    _windows.removeWhere((w) => !live.contains(w.windowId));
    if (_keyWindowId != null && !live.contains(_keyWindowId)) _setKey(null);
    if (_windows.length != before) _changed();
  }

  Future<Object?> _handle(String method, Map<String, Object?> args) async {
    final windowId = args['window_id'];
    switch (method) {
      case 'auth.headers':
        // Only a window of the server signed in to gets its credentials.
        ConversationWindowEntry? known() =>
            _windows.where((w) => w.windowId == windowId).firstOrNull;
        if (known() == null) await Future.wait([..._creating]);
        final window = known();
        if (window == null || !_isCurrent(window.args)) {
          if (windowId is String) {
            _drop(windowId);
            unawaited(_host.close(windowId));
          }
          return const <String, String>{};
        }
        final rejected = args['rejected'];
        return _headers(
          rejected: rejected is Map ? rejected.cast<String, String>() : null,
        );
      case 'focused':
        if (args['focused'] == true) {
          _setKey(windowId as String?);
        } else if (windowId == _keyWindowId) {
          _setKey(null);
        }
      case 'title':
        final title = args['title'];
        final pinned = args['pinned'] == true;
        final index = _windows.indexWhere((w) => w.windowId == windowId);
        if (index < 0 || title is! String) return null;
        final window = _windows[index];
        if (window.args.title == title && window.pinned == pinned) return null;
        _windows[index] = ConversationWindowEntry(
          window.windowId,
          window.args.withTitle(title),
          pinned: pinned,
        );
        if (window.args.title == title) {
          notifyListeners();
        } else {
          _changed();
        }
      case 'showInMain':
        final threadId = args['thread_id'];
        if (threadId is String) {
          _showInMain.add((
            threadId: threadId,
            profile: args['profile'] as String?,
          ));
        }
        await _host.showMain();
      case 'showMain':
        await _host.showMain();
    }
    return null;
  }

  void _setKey(String? windowId) {
    if (_keyWindowId == windowId) return;
    _keyWindowId = windowId;
    notifyListeners();
  }

  void _changed() {
    unawaited(_store.save(_windows.map((w) => w.args)));
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _mainFocused.close();
    _showInMain.close();
    super.dispose();
  }
}
