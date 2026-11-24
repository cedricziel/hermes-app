import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../macos/mac_commands.dart';
import 'desktop_menu_bar_settings.dart';
import 'desktop_menu_models.dart';
import 'widgets/desktop_menu_bar.dart';

/// Puts the [DesktopMenuBar] above [child] on Windows and Linux while the
/// "Show menu bar" setting is on, and is [child] alone otherwise: on a Mac,
/// iPhone, iPad and Android, and with the setting off, so the chat keeps its
/// height.
///
/// The items run their commands through the [MacCommandRegistry] of the
/// nearest [MacCommandScope.root], and are disabled while no screen offers an
/// enabled handler. The bar binds no key: `DesktopCommandShortcuts` owns the
/// chords and the items only show them.
class DesktopMenuBarHost extends StatelessWidget {
  const DesktopMenuBarHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = _settings(context);
    final registry = MacCommandScope.registryOf(context);
    if (settings == null ||
        registry == null ||
        !settings.enabled ||
        !DesktopMenuBarSettings.offeredOn(Theme.of(context).platform)) {
      return child;
    }
    return _BarOverEntry(registry: registry, child: child);
  }

  static DesktopMenuBarSettings? _settings(BuildContext context) {
    try {
      return context.watch<DesktopMenuBarSettings>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

/// The bar and [child] in an [Overlay] of their own: the menus open over the
/// whole window, and the app's [Navigator], which holds the only overlay the
/// app has, is below the bar.
class _BarOverEntry extends StatefulWidget {
  const _BarOverEntry({required this.registry, required this.child});

  final MacCommandRegistry registry;
  final Widget child;

  @override
  State<_BarOverEntry> createState() => _BarOverEntryState();
}

class _BarOverEntryState extends State<_BarOverEntry> {
  late final _entry = OverlayEntry(
    builder: (context) => Column(
      children: [
        ListenableBuilder(
          listenable: widget.registry,
          builder: (context, _) => DesktopMenuBar(
            menus: desktopMenus(widget.registry, context.l10n),
          ),
        ),
        Expanded(child: widget.child),
      ],
    ),
  );

  @override
  void didUpdateWidget(_BarOverEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
