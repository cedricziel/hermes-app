import 'dart:async';

import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';

/// Stands in for desktop_multi_window: records the windows opened and lets
/// a test close them, focus the main window and make calls as a window.
class FakeConversationWindowHost implements ConversationWindowHost {
  final created = <String, ConversationWindowArgs>{};
  final focused = <String>[];
  final commands = <(String, String)>[];
  var mainShown = 0;
  var _next = 0;
  final _live = StreamController<Set<String>>.broadcast(sync: true);
  final _mainFocus = StreamController<void>.broadcast(sync: true);
  ConversationWindowCallHandler? handler;

  @override
  Future<String> create(ConversationWindowArgs args) async {
    final id = 'w${_next++}';
    created[id] = args;
    return id;
  }

  @override
  Future<void> focus(String windowId) async => focused.add(windowId);

  @override
  Future<void> command(String windowId, String command) async =>
      commands.add((windowId, command));

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
    _live.add({'main', ...created.keys});
  }

  void focusMain() => _mainFocus.add(null);

  void dispose() {
    _live.close();
    _mainFocus.close();
  }

  Future<Object?> call(String method, Map<String, Object?> args) =>
      handler!(method, args);
}
