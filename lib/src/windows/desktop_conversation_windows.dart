import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'conversation_window_args.dart';
import 'conversation_windows.dart';

/// The channel conversation windows call the main window on.
const _mainChannel = WindowMethodChannel(
  'hermes_app/conversations',
  mode: ChannelMode.unidirectional,
);

/// The channel the main window sends a conversation window commands on.
WindowMethodChannel _windowChannel(String windowId) => WindowMethodChannel(
  'hermes_app/conversation/$windowId',
  mode: ChannelMode.unidirectional,
);

/// Each engine's own window: the main one in the main engine, a conversation
/// window in its engine.
const _nativeWindow = MethodChannel('hermes_app/window');

final StreamController<bool> _keyChangeController = StreamController.broadcast(
  onListen: () => _nativeWindow.setMethodCallHandler((call) async {
    if (call.method == 'keyChanged' && call.arguments is bool) {
      _keyChangeController.add(call.arguments as bool);
    }
  }),
);

/// Whether this engine's native window became (true) or stopped being
/// (false) the key window.
Stream<bool> get _keyChanges => _keyChangeController.stream;

/// [ConversationWindowHost] over desktop_multi_window, for the main engine.
class DesktopConversationWindowHost implements ConversationWindowHost {
  @override
  Future<String> create(ConversationWindowArgs args) async {
    final controller = await WindowController.create(
      WindowConfiguration(arguments: args.encode()),
    );
    return controller.windowId;
  }

  @override
  Future<void> focus(String windowId) =>
      WindowController.fromWindowId(windowId).show();

  @override
  Future<void> command(String windowId, String command) async {
    try {
      await _windowChannel(windowId).invokeMethod<void>(command);
    } on Object catch (error) {
      debugPrint('Conversation window $windowId did not take $command: $error');
    }
  }

  @override
  Future<void> close(String windowId) async {
    try {
      await _nativeWindow.invokeMethod<void>('closeConversation', windowId);
    } on Object catch (error) {
      debugPrint('Could not close conversation window $windowId: $error');
    }
  }

  @override
  Future<void> closeAll() async {
    try {
      await _nativeWindow.invokeMethod<void>('closeConversations');
    } on Object catch (error) {
      debugPrint('Could not close the conversation windows: $error');
    }
  }

  @override
  Future<void> showMain() => _nativeWindow.invokeMethod<void>('show');

  @override
  Stream<Set<String>> get liveWindows => onWindowsChanged.asyncMap(
    (_) async => {
      for (final window in await WindowController.getAll()) window.windowId,
    },
  );

  @override
  Stream<void> get mainFocused => _keyChanges.where((key) => key);

  @override
  void listen(ConversationWindowCallHandler handler) {
    unawaited(
      _mainChannel.setMethodCallHandler((call) {
        final args = call.arguments;
        return handler(
          call.method,
          args is Map ? args.cast<String, Object?>() : const {},
        );
      }),
    );
  }
}

/// What a conversation window asks of the main window and of its own native
/// window.
abstract interface class ConversationWindowLink {
  /// The auth headers for a request; see `WindowAuthInterceptor`.
  Future<Map<String, String>> headers({Map<String, String>? rejected});

  /// Thread actions, by name, the main window's menu bar sends; held until
  /// the screen listens.
  Stream<String> get commands;

  /// Whether this window became (true) or stopped being (false) key.
  Stream<bool> get keyChanges;

  void reportFocus(bool focused);

  /// Names the window after its chat, here and in the Window menu, and tells
  /// the menu bar whether the chat is pinned.
  void reportThread(String title, {required bool pinned});

  Future<void> showInMain(String threadId, String? profile);

  Future<void> showMain();

  /// Sets the window's frame autosave name (which restores its last frame)
  /// and shows it.
  Future<void> present({required String frameName, required String title});

  Future<void> close();

  /// Opens the share picker for [text], pointing at [anchor].
  Future<void> share(String text, Rect anchor);
}

/// [ConversationWindowLink] for the conversation window [windowId].
class DesktopConversationWindowLink implements ConversationWindowLink {
  DesktopConversationWindowLink(this.windowId) {
    unawaited(
      _windowChannel(windowId).setMethodCallHandler((call) async {
        _commands.add(call.method);
      }),
    );
  }

  final String windowId;
  final _commands = StreamController<String>();

  Future<T?> _main<T>(String method, [Map<String, Object?> args = const {}]) =>
      _mainChannel.invokeMethod<T>(method, {'window_id': windowId, ...args});

  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async {
    try {
      final headers = await _main<Map<Object?, Object?>>('auth.headers', {
        'rejected': rejected,
      });
      return headers?.cast<String, String>() ?? const {};
    } on Object catch (error) {
      debugPrint('The main window gave no auth headers: $error');
      return const {};
    }
  }

  @override
  Stream<String> get commands => _commands.stream;

  @override
  Stream<bool> get keyChanges => _keyChanges;

  @override
  void reportFocus(bool focused) =>
      unawaited(_quietly(_main<void>('focused', {'focused': focused})));

  @override
  void reportThread(String title, {required bool pinned}) {
    unawaited(
      _quietly(_main<void>('title', {'title': title, 'pinned': pinned})),
    );
    unawaited(_quietly(_nativeWindow.invokeMethod<void>('setTitle', title)));
  }

  @override
  Future<void> showInMain(String threadId, String? profile) => _quietly(
    _main<void>('showInMain', {'thread_id': threadId, 'profile': profile}),
  );

  @override
  Future<void> showMain() => _quietly(_main<void>('showMain'));

  @override
  Future<void> present({required String frameName, required String title}) =>
      _quietly(
        _nativeWindow.invokeMethod<void>('present', {
          'window_id': windowId,
          'frame_name': frameName,
          'title': title,
        }),
      );

  @override
  Future<void> close() => _quietly(_nativeWindow.invokeMethod<void>('close'));

  @override
  Future<void> share(String text, Rect anchor) => _quietly(
    _nativeWindow.invokeMethod<void>('share', {
      'text': text,
      'x': anchor.left,
      'y': anchor.top,
      'width': anchor.width,
      'height': anchor.height,
    }),
  );

  static Future<void> _quietly(Future<void> call) async {
    try {
      await call;
    } on Object catch (error) {
      debugPrint('Conversation window call failed: $error');
    }
  }
}
