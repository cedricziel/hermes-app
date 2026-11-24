import 'package:flutter/material.dart';

import '../macos/mac_commands.dart';
import '../macos/menu_layout.dart';
import 'keyboard_shortcuts.dart';
import 'modal_route_observer.dart';

class _CommandIntent extends Intent {
  const _CommandIntent(this.command, this.chord);

  final MacCommand command;
  final SingleActivator chord;
}

/// Every Windows and Linux chord of [menuLayout] with the command it runs.
final _bindings = <ShortcutActivator, Intent>{
  for (final section in menuLayout)
    for (final group in section.groupsOn(MenuPlatform.desktop))
      for (final entry in group)
        for (final chord in entry.shortcutsOn(MenuPlatform.desktop))
          chord: _CommandIntent(entry.command, chord),
};

/// The chords the platform's text editing binds for the field that has focus
/// (Alt+Left is the start of the line on Windows and Linux, Ctrl+Backspace
/// deletes a word), read from the framework's own `DefaultTextEditingShortcuts`
/// above it. The commands sit below those in the widget tree, so they would
/// take the key first. Empty when no field has focus.
List<SingleActivator> textEditingChords() {
  final focus = FocusManager.instance.primaryFocus?.context;
  if (focus == null ||
      focus.findAncestorStateOfType<EditableTextState>() == null) {
    return const [];
  }
  final chords = <SingleActivator>[];
  focus.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Shortcuts &&
        (widget.debugLabel?.contains('Default Text Editing') ?? false)) {
      for (final chord in widget.shortcuts.keys) {
        if (chord is SingleActivator) chords.add(chord);
      }
      return false;
    }
    return true;
  });
  return chords;
}

bool _sameChord(SingleActivator a, SingleActivator b) =>
    a.trigger == b.trigger &&
    a.control == b.control &&
    a.alt == b.alt &&
    a.shift == b.shift &&
    a.meta == b.meta;

/// Runs the commands of the menus from the keyboard on Windows and Linux,
/// through the [MacCommandRegistry] the screens already register with: the
/// chords are declared once, in [menuLayout], next to the Mac's.
///
/// A chord with no enabled handler is not taken, so the key goes on to
/// whatever has focus. Neither is a chord that text editing binds (Alt+Left,
/// Alt+Right, Alt+Up) while a text field has focus: the caret keeps it. Nothing here is bound on other platforms: a Mac's menu
/// bar and an iPad's menus bind their own chords.
class DesktopCommandShortcuts extends StatelessWidget {
  const DesktopCommandShortcuts({
    super.key,
    this.modalRoutes,
    required this.child,
  });

  /// The app's single [ModalRouteObserver]; with none, no dialog is known.
  final ModalRouteObserver? modalRoutes;

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
        actions: {_CommandIntent: _CommandAction(registry, modalRoutes)},
        child: child,
      ),
    );
  }
}

class _CommandAction extends Action<_CommandIntent> {
  _CommandAction(this.registry, this.modalRoutes);

  final MacCommandRegistry registry;
  final ModalRouteObserver? modalRoutes;

  @override
  bool isEnabled(_CommandIntent intent) =>
      !(modalRoutes?.modalOpen ?? false) &&
      (registry.handlerFor(intent.command)?.enabled ?? false) &&
      !textEditingChords().any((chord) => _sameChord(chord, intent.chord));

  @override
  void invoke(_CommandIntent intent) => registry.invoke(intent.command);
}
