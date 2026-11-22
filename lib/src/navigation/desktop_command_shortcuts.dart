import 'package:flutter/material.dart';

import '../macos/mac_commands.dart';
import '../macos/menu_layout.dart';
import 'keyboard_shortcuts.dart';

class _CommandIntent extends Intent {
  const _CommandIntent(this.command);

  final MacCommand command;
}

/// Every Windows and Linux chord of [menuLayout] with the command it runs.
final _bindings = <ShortcutActivator, Intent>{
  for (final section in menuLayout)
    for (final group in section.groupsOn(MenuPlatform.desktop))
      for (final entry in group)
        for (final chord in entry.shortcutsOn(MenuPlatform.desktop))
          chord: _CommandIntent(entry.command),
};

/// Runs the commands of the menus from the keyboard on Windows and Linux,
/// through the [MacCommandRegistry] the screens already register with: the
/// chords are declared once, in [menuLayout], next to the Mac's.
///
/// A chord with no enabled handler is not taken, so the key goes on to
/// whatever has focus. Nothing here is bound on other platforms: a Mac's menu
/// bar and an iPad's menus bind their own chords.
class DesktopCommandShortcuts extends StatelessWidget {
  const DesktopCommandShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final registry = MacCommandScope.registryOf(context);
    if (registry == null || !bindsDesktopChords(Theme.of(context).platform)) {
      return child;
    }
    return Shortcuts(
      shortcuts: _bindings,
      child: Actions(
        actions: {_CommandIntent: _CommandAction(registry)},
        child: child,
      ),
    );
  }
}

class _CommandAction extends Action<_CommandIntent> {
  _CommandAction(this.registry);

  final MacCommandRegistry registry;

  @override
  bool isEnabled(_CommandIntent intent) =>
      registry.handlerFor(intent.command)?.enabled ?? false;

  @override
  void invoke(_CommandIntent intent) => registry.invoke(intent.command);
}
