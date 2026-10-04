import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/about_dialog.dart';
import '../theme/platform_chrome.dart';
import 'mac_commands.dart';
import 'mac_window.dart';

final _helpUrl = Uri.parse('https://github.com/cedricziel/hermes-app#readme');

/// The macOS menu bar (Hermes, File, Edit, View, Chat, Window, Help) and the
/// [MacCommandRegistry] its items act through.
///
/// The registry is provided everywhere so screens can register without
/// checking the platform; the native menu is only set in a Mac window
/// ([MacWindow.enabled]), which tests leave off unless they answer the menu
/// channel.
class MacMenuBar extends StatefulWidget {
  const MacMenuBar({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// Gives dialogs opened from the menu a context under the navigator.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<MacMenuBar> createState() => _MacMenuBarState();
}

class _MacMenuBarState extends State<MacMenuBar> {
  final _registry = MacCommandRegistry();
  late final _rootCommands = {
    MacCommand.about: MacCommandHandler(_about),
    MacCommand.help: MacCommandHandler(_help),
    MacCommand.closeWindow: const MacCommandHandler(MacWindow.close),
    MacCommand.showMainWindow: const MacCommandHandler(MacWindow.orderFront),
  };

  /// The menus as last built. [PlatformMenuBar] sends its menus to the
  /// platform whenever it gets a new list, so the list is only rebuilt when
  /// the registry changes, not when a theme animation rebuilds this widget.
  List<PlatformMenuItem>? _menus;

  @override
  void initState() {
    super.initState();
    _registry.addListener(_registryChanged);
  }

  void _registryChanged() => setState(() => _menus = null);

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  void _about() {
    final context = widget.navigatorKey.currentContext;
    if (context != null) showAppAboutDialog(context);
  }

  Future<void> _help() async {
    try {
      await launchUrl(_helpUrl, mode: LaunchMode.externalApplication);
    } on Object catch (_) {
      // Nothing to do when the browser cannot be opened.
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = MacCommandScope.root(
      registry: _registry,
      child: MacCommandScope(commands: _rootCommands, child: widget.child),
    );
    if (!MacWindow.enabled ||
        platformChromeOf(context) != PlatformChrome.macos) {
      return content;
    }
    return PlatformMenuBar(
      menus: _menus ??= macMenus(_registry),
      child: content,
    );
  }
}

/// The menus of the Mac menu bar, each item enabled while [registry] has a
/// handler for its command.
List<PlatformMenuItem> macMenus(MacCommandRegistry registry) {
  PlatformMenuItem item(
    MacCommand command,
    String label, {
    MenuSerializableShortcut? shortcut,
  }) {
    final handler = registry.handlerFor(command);
    final enabled = handler?.enabled ?? false;
    return PlatformMenuItem(
      label: handler?.title ?? label,
      shortcut: shortcut,
      onSelected: enabled ? () => registry.invoke(command) : null,
    );
  }

  PlatformMenuItem edit(
    String label,
    Intent intent,
    MenuSerializableShortcut shortcut,
  ) => PlatformMenuItem(
    label: label,
    shortcut: shortcut,
    onSelected: () => _invokeOnFocus(intent),
  );

  PlatformProvidedMenuItem provided(PlatformProvidedMenuItemType type) =>
      PlatformProvidedMenuItem(type: type);

  PlatformMenuItemGroup group(List<PlatformMenuItem> members) =>
      PlatformMenuItemGroup(members: members);

  const cause = SelectionChangedCause.keyboard;
  return [
    PlatformMenu(
      label: 'Hermes',
      menus: [
        group([item(MacCommand.about, 'About Hermes')]),
        group([
          item(
            MacCommand.settings,
            'Settings…',
            shortcut: _meta(LogicalKeyboardKey.comma),
          ),
        ]),
        group([provided(PlatformProvidedMenuItemType.servicesSubmenu)]),
        group([
          provided(PlatformProvidedMenuItemType.hide),
          provided(PlatformProvidedMenuItemType.hideOtherApplications),
          provided(PlatformProvidedMenuItemType.showAllApplications),
        ]),
        group([provided(PlatformProvidedMenuItemType.quit)]),
      ],
    ),
    PlatformMenu(
      label: 'File',
      menus: [
        group([
          item(
            MacCommand.newChat,
            'New Chat',
            shortcut: _meta(LogicalKeyboardKey.keyN),
          ),
          item(
            MacCommand.openInNewWindow,
            'Open in New Window',
            shortcut: _meta(LogicalKeyboardKey.keyO, alt: true),
          ),
        ]),
        group([
          item(
            MacCommand.closeWindow,
            'Close Window',
            shortcut: _meta(LogicalKeyboardKey.keyW),
          ),
        ]),
      ],
    ),
    PlatformMenu(
      label: 'Edit',
      menus: [
        group([
          edit(
            'Undo',
            const UndoTextIntent(cause),
            _meta(LogicalKeyboardKey.keyZ),
          ),
          edit(
            'Redo',
            const RedoTextIntent(cause),
            _meta(LogicalKeyboardKey.keyZ, shift: true),
          ),
        ]),
        group([
          edit(
            'Cut',
            const CopySelectionTextIntent.cut(cause),
            _meta(LogicalKeyboardKey.keyX),
          ),
          edit(
            'Copy',
            CopySelectionTextIntent.copy,
            _meta(LogicalKeyboardKey.keyC),
          ),
          edit(
            'Paste',
            const PasteTextIntent(cause),
            _meta(LogicalKeyboardKey.keyV),
          ),
          edit(
            'Select All',
            const SelectAllTextIntent(cause),
            _meta(LogicalKeyboardKey.keyA),
          ),
        ]),
      ],
    ),
    PlatformMenu(
      label: 'View',
      menus: [
        group([
          item(
            MacCommand.toggleSidebar,
            'Show Sidebar',
            shortcut: _meta(LogicalKeyboardKey.keyS, control: true),
          ),
          item(
            MacCommand.toggleInspector,
            'Show Inspector',
            shortcut: _meta(LogicalKeyboardKey.keyI, alt: true),
          ),
        ]),
        group([provided(PlatformProvidedMenuItemType.toggleFullScreen)]),
      ],
    ),
    PlatformMenu(
      label: 'Chat',
      menus: [
        group([
          item(
            MacCommand.find,
            'Find…',
            shortcut: _meta(LogicalKeyboardKey.keyF),
          ),
        ]),
        group([
          item(
            MacCommand.pinThread,
            'Pin',
            shortcut: _meta(LogicalKeyboardKey.keyP, shift: true),
          ),
          item(MacCommand.renameThread, 'Rename…'),
          item(MacCommand.copyTranscript, 'Copy Transcript'),
        ]),
        group([
          item(MacCommand.archiveThread, 'Archive'),
          PlatformMenuItem(
            label: 'Delete…',
            shortcut: _meta(LogicalKeyboardKey.backspace),
            onSelected:
                registry.handlerFor(MacCommand.deleteThread)?.enabled ?? false
                ? _deleteThreadOrLine(registry)
                : null,
          ),
        ]),
      ],
    ),
    PlatformMenu(
      label: 'Window',
      menus: [
        group([
          provided(PlatformProvidedMenuItemType.minimizeWindow),
          provided(PlatformProvidedMenuItemType.zoomWindow),
        ]),
        group([
          item(
            MacCommand.showMainWindow,
            'Hermes',
            shortcut: _meta(LogicalKeyboardKey.digit0),
          ),
          for (final window in registry.windows)
            PlatformMenuItem(
              label: window.title,
              onSelected: () => _selectWindow(registry, window.id),
            ),
        ]),
        group([provided(PlatformProvidedMenuItemType.arrangeWindowsInFront)]),
      ],
    ),
    PlatformMenu(label: 'Help', menus: [item(MacCommand.help, 'Hermes Help')]),
  ];
}

SingleActivator _meta(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
  bool control = false,
}) =>
    SingleActivator(key, meta: true, shift: shift, alt: alt, control: control);

// The entry's callback is read when it is picked, not when the menu was set,
// so a window that changed its callback since still gets the newest one.
void _selectWindow(MacCommandRegistry registry, String id) {
  for (final window in registry.windows) {
    if (window.id == id) return window.onSelect();
  }
}

// Command-Delete deletes to the line start in a text field, so there the menu
// item does that instead of deleting the chat.
VoidCallback _deleteThreadOrLine(MacCommandRegistry registry) => () {
  if (_editingText()) {
    _invokeOnFocus(const DeleteToLineBreakIntent(forward: false));
  } else {
    registry.invoke(MacCommand.deleteThread);
  }
};

bool _editingText() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>() !=
    null;

void _invokeOnFocus(Intent intent) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context != null) Actions.maybeInvoke(context, intent);
}
