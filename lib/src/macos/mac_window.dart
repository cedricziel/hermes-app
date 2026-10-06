import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

/// The height of the unified toolbar area at the top of a macOS window, which
/// the traffic lights are centred in.
const double kMacToolbarHeight = 52;

/// The room the traffic lights take at the left edge of the window.
const double kMacTrafficLightsWidth = 78;

const _channel = MethodChannel('hermes_app/window');

/// The macOS window around the app: a transparent title bar over a full-size
/// content view, so the sidebar can start at the top of the window.
abstract final class MacWindow {
  /// Whether the window has been set up. False in tests and off macOS, where
  /// nothing here may touch a native window.
  static bool enabled = false;

  /// The native title bar's height, which the content view extends under.
  static double titlebarHeight = 28;

  /// Whether this engine runs a conversation window, whose chrome its runner
  /// sets up natively. macos_window_utils works on the main window only.
  static bool _conversation = false;

  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      await WindowManipulator.initialize();
      await WindowManipulator.makeTitlebarTransparent();
      await WindowManipulator.enableFullSizeContentView();
      await WindowManipulator.hideTitle();
      await WindowManipulator.setMaterial(
        NSVisualEffectViewMaterial.windowBackground,
      );
      await WindowManipulator.addToolbar();
      await WindowManipulator.setToolbarStyle(
        toolbarStyle: NSWindowToolbarStyle.unified,
      );
      final height = await WindowManipulator.getTitlebarHeight();
      if (height > 0) titlebarHeight = height;
      enabled = true;
    } on Object catch (error, stack) {
      debugPrint('Mac window setup failed: $error\n$stack');
    }
  }

  /// Sets up a conversation window's engine, whose window the runner has
  /// already given its transparent title bar and toolbar.
  static Future<void> initializeConversationWindow() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      final height = await _channel.invokeMethod<double>('titlebarHeight');
      if (height != null && height > 0) titlebarHeight = height;
      _conversation = true;
      enabled = true;
    } on Object catch (error) {
      debugPrint('Conversation window setup failed: $error');
    }
  }

  /// Makes the system materials follow the app's theme, not the system's.
  static Future<void> follow(Brightness brightness) => _run(
    'brightness',
    () => _conversation
        ? _channel.invokeMethod<void>(
            'setAppearance',
            brightness == Brightness.dark,
          )
        : WindowManipulator.overrideMacOSBrightness(
            dark: brightness == Brightness.dark,
          ),
  );

  /// Closes the window as its close button does.
  static Future<void> close() => _run(
    'close',
    () => _conversation
        ? _channel.invokeMethod<void>('close')
        : WindowManipulator.performClose(),
  );

  static Future<void> orderFront() =>
      _run('order front', WindowManipulator.orderFront);

  static Future<void> _run(String what, Future<void> Function() call) async {
    if (!enabled) return;
    try {
      await call();
    } on Object catch (error) {
      debugPrint('Mac window $what failed: $error');
    }
  }

  static Future<void> startDrag() =>
      _run('drag', () => _channel.invokeMethod<void>('startDrag'));
}

/// Wraps the app so that, on macOS, its screens clear the title bar and the
/// window's materials follow the app's theme.
class MacWindowChrome extends StatefulWidget {
  const MacWindowChrome({super.key, required this.child});

  final Widget child;

  @override
  State<MacWindowChrome> createState() => _MacWindowChromeState();
}

class _MacWindowChromeState extends State<MacWindowChrome> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MacWindow.follow(Theme.of(context).brightness);
  }

  @override
  Widget build(BuildContext context) {
    if (!MacWindow.enabled) return widget.child;
    final media = MediaQuery.of(context);
    final top = MacWindow.titlebarHeight;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: top),
        viewPadding: media.viewPadding.copyWith(top: top),
      ),
      child: widget.child,
    );
  }
}

/// Lets the window be dragged by the area it covers, as a title bar does.
class MacWindowDragArea extends StatelessWidget {
  const MacWindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (_) => MacWindow.startDrag(),
    child: child,
  );
}
