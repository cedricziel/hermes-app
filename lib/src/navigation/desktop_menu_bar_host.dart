import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../macos/mac_commands.dart';
import 'desktop_menu_bar_settings.dart';
import 'desktop_menu_models.dart';
import 'modal_route_observer.dart';
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
  const DesktopMenuBarHost({super.key, this.modalRoutes, required this.child});

  /// Which modal routes are open on the app's navigator; the items are
  /// disabled while one is, since the bar is above the navigator and a
  /// dialog's barrier does not cover it.
  final ModalRouteObserver? modalRoutes;

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
    return _BarOverEntry(
      registry: registry,
      modalRoutes: modalRoutes,
      child: child,
    );
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
  const _BarOverEntry({
    required this.registry,
    required this.modalRoutes,
    required this.child,
  });

  final MacCommandRegistry registry;
  final ModalRouteObserver? modalRoutes;
  final Widget child;

  @override
  State<_BarOverEntry> createState() => _BarOverEntryState();
}

class _BarOverEntryState extends State<_BarOverEntry> {
  final _bar = DesktopMenuBarController();

  late final _entry = OverlayEntry(
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([widget.registry, widget.modalRoutes]),
      builder: (context, _) {
        final menus = desktopMenus(widget.registry, context.l10n);
        final modalOpen = widget.modalRoutes?.modalOpen ?? false;
        // F10 is the chord of MacCommand.focusMenuBar in menuLayout, which
        // DesktopCommandShortcuts binds while a handler is registered. A
        // scope registers it like any screen's commands: only while the bar
        // shows on screen (not under the App Lock cover, where tickers are
        // off) and no dialog is open, and the key is left to the focused
        // widget otherwise.
        return MacCommandScope(
          commands: {
            MacCommand.focusMenuBar: MacCommandHandler(
              modalOpen ? null : _bar.focusFirstMenu,
            ),
          },
          child: Column(
            children: [
              DesktopMenuBar(
                controller: _bar,
                menus: modalOpen
                    ? [for (final menu in menus) menu.inert()]
                    : menus,
              ),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
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
