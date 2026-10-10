import 'dart:async';

import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';

/// Stands in for desktop_multi_window: records the windows opened and lets
/// a test close them, focus the main window and make calls as a window.
class FakeConversationWindowHost implements ConversationWindowHost {
  final created = <String, ConversationWindowArgs>{};

  /// The draft each window was started with, by id.
  final drafts = <String, ConversationDraft?>{};
  final focused = <String>[];
  final commands = <(String, String)>[];

  /// The windows closed natively, by id; `*` for all at once.
  final closedNatively = <String>[];
  var mainShown = 0;

  /// The quick panels created, by id, and how often the open one was
  /// toggled.
  final panels = <String, QuickPanelLaunch>{};
  var panelToggles = 0;
  var _next = 0;
  final _live = StreamController<Set<String>>.broadcast(sync: true);
  final _mainFocus = StreamController<void>.broadcast(sync: true);
  ConversationWindowCallHandler? handler;

  /// Runs while a window is being created, before its id comes back.
  Future<void> Function(ConversationWindowArgs args)? onCreate;

  @override
  Future<String> create(
    ConversationWindowArgs args, {
    ConversationDraft? draft,
  }) async {
    await onCreate?.call(args);
    final id = 'w${_next++}';
    created[id] = args;
    drafts[id] = draft;
    return id;
  }

  @override
  Future<String> createPanel(QuickPanelLaunch launch) async {
    final id = 'p${_next++}';
    panels[id] = launch;
    return id;
  }

  /// Like the native side, false while no panel is open.
  @override
  Future<bool> togglePanel() async {
    if (panels.isEmpty) return false;
    panelToggles++;
    return true;
  }

  /// Like the plugin, fails for a window it no longer knows.
  @override
  Future<void> focus(String windowId) async {
    if (!created.containsKey(windowId)) {
      throw StateError('failed to find target window. $windowId');
    }
    focused.add(windowId);
  }

  @override
  Future<void> command(String windowId, String command) async =>
      commands.add((windowId, command));

  @override
  Future<void> close(String windowId) async {
    closedNatively.add(windowId);
    created.remove(windowId);
    panels.remove(windowId);
  }

  @override
  Future<void> closeAll() async {
    closedNatively.add('*');
    created.clear();
    panels.clear();
  }

  @override
  Future<void> showMain() async => mainShown++;

  @override
  Stream<Set<String>> get liveWindows => _live.stream;

  @override
  Stream<void> get mainFocused => _mainFocus.stream;

  @override
  void listen(ConversationWindowCallHandler handler) => this.handler = handler;

  void closed(String id) {
    created.remove(id);
    panels.remove(id);
    _live.add({'main', ...created.keys, ...panels.keys});
  }

  /// The window went away without the main engine hearing of it.
  void vanished(String id) => created.remove(id);

  void focusMain() => _mainFocus.add(null);

  void dispose() {
    _live.close();
    _mainFocus.close();
  }

  Future<Object?> call(String method, Map<String, Object?> args) =>
      handler!(method, args);
}
