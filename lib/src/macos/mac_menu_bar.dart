import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show noopAppEventLogger;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../api/hermes_repositories.dart';
import '../settings/about_dialog.dart';
import '../telemetry/breadcrumbs.dart';
import '../theme/platform_chrome.dart';
import 'edit_menu_state.dart';
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
  final _edit = EditMenuState();
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
  AppLocalizations? _l10n;

  IpadMenuBridge? _ipad;

  @override
  void initState() {
    super.initState();
    _registry.addListener(_registryChanged);
    _edit.addListener(_registryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    if (_l10n != l10n) {
      // A new language: the menus are built again, and the iPad gets the
      // layout again with its new labels.
      _l10n = l10n;
      _menus = null;
      _ipad?.l10n = l10n;
    }
    final ios = platformChromeOf(context) == PlatformChrome.ios;
    if (ios && _ipad == null) {
      _ipad = IpadMenuBridge(
        registry: _registry,
        localizations: l10n,
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
    _edit.dispose();
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
    } on Exception {
      // Nothing to do when the browser cannot be opened; a bug is not hidden.
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = InheritedProvider<EditMenuState>.value(
      value: _edit,
      child: MacCommandScope.root(
        registry: _registry,
        child: MacCommandScope(commands: _rootCommands, child: widget.child),
      ),
    );
    if (!MacWindow.enabled ||
        platformChromeOf(context) != PlatformChrome.macos) {
      return content;
    }
    return PlatformMenuBar(
      menus: _menus ??= macMenus(_registry, context.l10n, _edit),
      child: content,
    );
  }
}

/// The menus of the Mac menu bar, each item enabled while [registry] has a
/// handler for its command.
///
/// The Edit items follow [editMenu]: each is off while what has focus cannot
/// take it, and all are off without one.
List<PlatformMenuItem> macMenus(
  MacCommandRegistry registry,
  AppLocalizations l10n, [
  EditMenuState? editMenu,
]) {
  final available = editMenu?.value ?? EditAvailability.none;
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
    entry.label(l10n),
    shortcut: entry.shortcutOn(MenuPlatform.mac),
    run: entry.command == MacCommand.deleteThread
        ? _deleteThreadOrLine(registry)
        : null,
  );

  PlatformMenuItem edit(
    String label,
    MenuSerializableShortcut shortcut, {
    required bool enabled,
    required VoidCallback run,
  }) => PlatformMenuItem(
    label: label,
    shortcut: shortcut,
    onSelected: enabled ? run : null,
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
      label: section.label(l10n),
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
      label: l10n.macosMenuEdit,
      menus: [
        group([
          edit(
            l10n.macosMenuUndo,
            metaActivator(LogicalKeyboardKey.keyZ),
            enabled: available.undo,
            run: () => editMenu?.undo(),
          ),
          edit(
            l10n.macosMenuRedo,
            metaActivator(LogicalKeyboardKey.keyZ, shift: true),
            enabled: available.redo,
            run: () => editMenu?.redo(),
          ),
        ]),
        group([
          edit(
            l10n.macosMenuCut,
            metaActivator(LogicalKeyboardKey.keyX),
            enabled: available.cut,
            run: () => _invokeOnFocus(const CopySelectionTextIntent.cut(cause)),
          ),
          edit(
            l10n.macosMenuCopy,
            metaActivator(LogicalKeyboardKey.keyC),
            enabled: available.copy,
            run: () => _invokeOnFocus(CopySelectionTextIntent.copy),
          ),
          edit(
            l10n.macosMenuPaste,
            metaActivator(LogicalKeyboardKey.keyV),
            enabled: available.paste,
            run: () => _invokeOnFocus(const PasteTextIntent(cause)),
          ),
          edit(
            l10n.macosMenuSelectAll,
            metaActivator(LogicalKeyboardKey.keyA),
            enabled: available.selectAll,
            run: () => _invokeOnFocus(const SelectAllTextIntent(cause)),
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
      label: l10n.macosMenuWindow,
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

bool _editingText() => EditMenuState.focusedField() != null;

void _invokeOnFocus(Intent intent) => EditMenuState.invokeOnFocus(intent);
