import 'package:flutter/widgets.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/desktop_command_shortcuts.dart';

/// A [MaterialApp.builder] that gives the screens under it [commands] to
/// register their menu bar commands with, or none without it. With
/// [desktopKeys] the Windows and Linux chords run them, as in the app.
TransitionBuilder? macCommandsBuilder(
  MacCommandRegistry? commands, {
  bool desktopKeys = false,
}) => commands == null
    ? null
    : (_, child) => MacCommandScope.root(
        registry: commands,
        child: desktopKeys ? DesktopCommandShortcuts(child: child!) : child!,
      );
