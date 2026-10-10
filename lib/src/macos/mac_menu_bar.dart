import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show noopAppEventLogger;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/hermes_repositories.dart';
import '../settings/about_dialog.dart';
import '../telemetry/breadcrumbs.dart';
import '../theme/platform_chrome.dart';
import 'ipad_menu_bridge.dart';
import 'mac_commands.dart';
import 'mac_window.dart';
import 'menu_layout.dart';

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

  IpadMenuBridge? _ipad;

  @override
  void initState() {
    super.initState();
    _registry.addListener(_registryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ios = platformChromeOf(context) == PlatformChrome.ios;
    if (ios && _ipad == null) {
      _ipad = IpadMenuBridge(
        registry: _registry,
        breadcrumbs: _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
        events: () =>
            HermesRepositories.maybeOf(context)?.telemetry.events ??
            noopAppEventLogger,
      )..start();
    } else if (!ios) {
      _ipad?.dispose();
      _ipad = null;
    }
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _registryChanged() => setState(() => _menus = null);

  @override
  void dispose() {
    _ipad?.dispose();
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
    VoidCallback? run,
  }) {
    final handler = registry.handlerFor(command);
    return PlatformMenuItem(
      label: handler?.title ?? label,
      shortcut: shortcut,
      onSelected: handler?.enabled ?? false
          ? run ?? () => registry.invoke(command)
          : null,
    );
  }

  PlatformMenuItem entryItem(MenuEntry entry) => item(
    entry.command,
    entry.label,
    shortcut: entry.shortcutOn(MenuPlatform.mac),
    run: entry.command == MacCommand.deleteThread
        ? _deleteThreadOrLine(registry)
        : null,
  );

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

  PlatformMenu section(
    String id, {
    List<PlatformMenuItemGroup> after = const [],
  }) {
    final section = menuLayout.firstWhere((s) => s.id == id);
    return PlatformMenu(
      label: section.label,
      menus: [
        for (final entries in section.groupsOn(MenuPlatform.mac))
          group([for (final entry in entries) entryItem(entry)]),
        ...after,
      ],
    );
  }

  const cause = SelectionChangedCause.keyboard;
  return [
    section(
      'hermes',
      after: [
        group([provided(PlatformProvidedMenuItemType.servicesSubmenu)]),
        group([
          provided(PlatformProvidedMenuItemType.hide),
          provided(PlatformProvidedMenuItemType.hideOtherApplications),
          provided(PlatformProvidedMenuItemType.showAllApplications),
        ]),
        group([provided(PlatformProvidedMenuItemType.quit)]),
      ],
    ),
    section('file'),
    PlatformMenu(
      label: 'Edit',
      menus: [
        group([
          edit(
            'Undo',
            const UndoTextIntent(cause),
            metaActivator(LogicalKeyboardKey.keyZ),
          ),
          edit(
            'Redo',
            const RedoTextIntent(cause),
            metaActivator(LogicalKeyboardKey.keyZ, shift: true),
          ),
        ]),
        group([
          edit(
            'Cut',
            const CopySelectionTextIntent.cut(cause),
            metaActivator(LogicalKeyboardKey.keyX),
          ),
          edit(
            'Copy',
            CopySelectionTextIntent.copy,
            metaActivator(LogicalKeyboardKey.keyC),
          ),
          edit(
            'Paste',
            const PasteTextIntent(cause),
            metaActivator(LogicalKeyboardKey.keyV),
          ),
          edit(
            'Select All',
            const SelectAllTextIntent(cause),
            metaActivator(LogicalKeyboardKey.keyA),
          ),
        ]),
      ],
    ),
    section(
      'view',
      after: [
        group([provided(PlatformProvidedMenuItemType.toggleFullScreen)]),
      ],
    ),
    section('chat'),
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
            shortcut: metaActivator(LogicalKeyboardKey.digit0),
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
    section('help'),
  ];
}

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
