import 'package:flutter/widgets.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';

/// A [MaterialApp.builder] that gives the screens under it [commands] to
/// register their menu bar commands with, or none without it.
TransitionBuilder? macCommandsBuilder(MacCommandRegistry? commands) =>
    commands == null
    ? null
    : (_, child) => MacCommandScope.root(registry: commands, child: child!);
