import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../macos/mac_commands.dart';
import 'desktop_navigation_history.dart';

class DesktopNavigationCommands extends StatelessWidget {
  const DesktopNavigationCommands({
    super.key,
    required this.history,
    required this.child,
  });
  final DesktopNavigationHistory history;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: history,
    builder: (context, _) => MacCommandScope(
      priority: 1,
      commands: {
        MacCommand.back: MacCommandHandler(
          history.canGoBack ? () => unawaited(history.back()) : null,
        ),
        MacCommand.forward: MacCommandHandler(
          history.canGoForward ? () => unawaited(history.forward()) : null,
        ),
      },
      child: Listener(
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.mouse) return;
          final command = switch (event.buttons &
              (kBackMouseButton | kForwardMouseButton)) {
            kBackMouseButton => MacCommand.back,
            kForwardMouseButton => MacCommand.forward,
            _ => null,
          };
          if (command != null) {
            MacCommandScope.registryOf(context)?.invoke(command);
          }
        },
        child: child,
      ),
    ),
  );
}
