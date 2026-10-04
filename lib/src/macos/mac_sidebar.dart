import 'package:flutter/material.dart';
import 'package:macos_window_utils/widgets/transparent_macos_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shell/shell_navigation.dart';
import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'mac_commands.dart';
import 'mac_toolbar.dart';
import 'mac_window.dart';

const double kMacSidebarMinWidth = 220;
const double kMacSidebarMaxWidth = 360;
const double kMacSidebarDefaultWidth = 280;

/// Below this window width the sidebar does not sit beside the content; it
/// opens over it.
const double kMacCompactWindowWidth = 760;

/// Whether the window around [context] is too narrow for a docked sidebar.
bool isMacCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kMacCompactWindowWidth;

/// Whether [context] is in a Mac window with a [MacSidebarScope], which keeps
/// its sidebar at every width: docked, or over the content when compact.
bool hasMacSidebar(BuildContext context) =>
    platformChromeOf(context) == PlatformChrome.macos &&
    MacSidebarScope.read(context) != null;

const _widthKey = 'hermes.mac_sidebar_width';
const _collapsedKey = 'hermes.mac_sidebar_collapsed';
const _sectionsKey = 'hermes.mac_sidebar_folded_sections';

/// Whether the sidebar of a Mac window is shown, how wide, and which of its
/// sections are folded away.
class MacSidebarController extends ChangeNotifier {
  MacSidebarController({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  double _width = kMacSidebarDefaultWidth;
  bool _collapsed = false;
  bool _touched = false;

  /// Which sections are folded. Apart from the rest, so a resize does not
  /// rebuild the lists that only care about the sections.
  late final sections = MacSidebarSections._(this);

  double get width => _width;
  bool get collapsed => _collapsed;

  Future<void> load() async {
    final (width, collapsed, folded) = await (
      _prefs.getDouble(_widthKey),
      _prefs.getBool(_collapsedKey),
      _prefs.getStringList(_sectionsKey),
    ).wait;
    sections._restore(folded);
    if (!_touched) {
      _width = (width ?? _width).clamp(
        kMacSidebarMinWidth,
        kMacSidebarMaxWidth,
      );
      _collapsed = collapsed ?? _collapsed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    sections.dispose();
    super.dispose();
  }

  bool _overlayOpen = false;

  /// Whether the sidebar is open over the content of a compact window.
  bool get overlayOpen => _overlayOpen;

  /// Whether the sidebar is out of sight in a window of this size.
  bool hidden({required bool compact}) => compact ? !_overlayOpen : _collapsed;

  /// Hides or shows the sidebar: docked in a wide window, over the content
  /// in a [compact] one.
  void toggle({bool compact = false}) {
    if (compact) {
      _overlayOpen = !_overlayOpen;
      notifyListeners();
      return;
    }
    _touched = true;
    _collapsed = !_collapsed;
    notifyListeners();
    _prefs.setBool(_collapsedKey, _collapsed);
  }

  /// Closes the sidebar over the content, after something in it was picked.
  void closeOverlay() {
    if (!_overlayOpen) return;
    _overlayOpen = false;
    notifyListeners();
  }

  void resizeTo(double width) {
    _touched = true;
    final next = width.clamp(kMacSidebarMinWidth, kMacSidebarMaxWidth);
    if (next == _width) return;
    _width = next;
    notifyListeners();
  }

  void saveWidth() => _prefs.setDouble(_widthKey, _width);
}

/// The sections of a Mac sidebar the user folded away, kept across launches.
class MacSidebarSections extends ChangeNotifier {
  MacSidebarSections._(this._owner);

  final MacSidebarController _owner;
  final _folded = <String>{};
  bool _touched = false;

  bool isCollapsed(String section) => _folded.contains(section);

  void toggle(String section) {
    _touched = true;
    if (!_folded.remove(section)) _folded.add(section);
    notifyListeners();
    _owner._prefs.setStringList(_sectionsKey, _folded.toList());
  }

  void _restore(List<String>? folded) {
    if (_touched || folded == null) return;
    _folded.addAll(folded);
    notifyListeners();
  }
}

/// Owns the [MacSidebarController] for a Mac window and offers the View
/// menu's Show/Hide Sidebar command (Control-Command-S).
class MacSidebarScope extends StatefulWidget {
  const MacSidebarScope({super.key, this.controller, required this.child});

  /// A controller the caller owns, for a catalog or a test; by default the
  /// scope makes and disposes its own.
  final MacSidebarController? controller;
  final Widget child;

  /// The controller above [context], or null where the window has no
  /// collapsible sidebar.
  static MacSidebarController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ControllerScope>()?.notifier;

  static MacSidebarController of(BuildContext context) => maybeOf(context)!;

  /// The controller above [context] without listening to it, for a callback
  /// or a check that does not change with the sidebar.
  static MacSidebarController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ControllerScope>()?.notifier;

  /// The folded sections of the sidebar above [context], without rebuilding
  /// [context] when the sidebar is resized or hidden.
  static MacSidebarSections? sectionsOf(BuildContext context) =>
      read(context)?.sections;

  @override
  State<MacSidebarScope> createState() => _MacSidebarScopeState();
}

class _MacSidebarScopeState extends State<MacSidebarScope> {
  late final _controller = widget.controller ?? MacSidebarController();

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, child) {
      final compact = isMacCompact(context);
      return MacCommandScope(
        commands: {
          MacCommand.toggleSidebar: MacCommandHandler(
            () => _controller.toggle(compact: compact),
            title: _controller.hidden(compact: compact)
                ? 'Show Sidebar'
                : 'Hide Sidebar',
          ),
        },
        child: child!,
      );
    },
    child: _ControllerScope(notifier: _controller, child: widget.child),
  );
}

class _ControllerScope extends InheritedNotifier<MacSidebarController> {
  const _ControllerScope({required super.notifier, required super.child});
}

class _SidebarSlot extends InheritedWidget {
  const _SidebarSlot({required this.translucent, required super.child});

  final bool translucent;

  @override
  bool updateShouldNotify(_SidebarSlot oldWidget) =>
      translucent != oldWidget.translucent;
}

bool _inSidebar(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_SidebarSlot>() != null;

/// The colour a sidebar paints behind its rows: none inside a Mac sidebar,
/// whose material shows through, [fallback] elsewhere.
Color macSidebarColor(BuildContext context, Color fallback) {
  final slot = context.dependOnInheritedWidgetOfExactType<_SidebarSlot>();
  return slot != null && slot.translucent ? Colors.transparent : fallback;
}

/// The top row of a sidebar in a Mac window: clear of the traffic lights, with
/// the button that hides the sidebar. Null outside one, where the sidebar
/// keeps its own heading.
Widget? macSidebarHeader(BuildContext context) {
  if (!_inSidebar(context)) return null;
  final controller = MacSidebarScope.maybeOf(context);
  return MacWindowDragArea(
    child: SizedBox(
      height: kMacToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: kMacTrafficLightsWidth),
          const Spacer(),
          if (controller != null) MacSidebarToggle(controller: controller),
          const SizedBox(width: 8),
        ],
      ),
    ),
  );
}

/// The toolbar button that hides or shows the sidebar.
class MacSidebarToggle extends StatelessWidget {
  const MacSidebarToggle({super.key, required this.controller});

  final MacSidebarController controller;

  @override
  Widget build(BuildContext context) {
    final compact = isMacCompact(context);
    return MacToolbarButton(
      key: const Key('mac-sidebar-toggle'),
      label: controller.hidden(compact: compact)
          ? 'Show sidebar'
          : 'Hide sidebar',
      shortcut: '⌃⌘S',
      icon: AppIcons.sidebar,
      onPressed: () => controller.toggle(compact: compact),
    );
  }
}

/// A sidebar beside its content, as in a Mac app: the sidebar sits on the
/// system's sidebar material behind the traffic lights, can be dragged wider
/// or narrower and can be hidden. In a compact window it opens over the
/// content instead, with a scrim that closes it. Without a [MacSidebarScope]
/// it is a fixed column.
class MacSplitView extends StatelessWidget {
  const MacSplitView({super.key, required this.sidebar, required this.content});

  final Widget sidebar;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final controller = MacSidebarScope.maybeOf(context);
    if (controller == null) {
      return Row(
        children: [
          SizedBox(width: kMacSidebarDefaultWidth, child: sidebar),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      );
    }
    final compact = isMacCompact(context);
    final collapsed = compact || controller.collapsed;
    final translucent = MacWindow.enabled;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: 0),
        viewPadding: media.viewPadding.copyWith(top: 0),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              if (!collapsed) ...[
                SizedBox(
                  width: controller.width,
                  child: _SidebarSlot(
                    translucent: translucent,
                    child: translucent
                        ? TransparentMacOSSidebar(child: sidebar)
                        : sidebar,
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Theme(
                  data: _toolbarTheme(context, collapsed),
                  child: collapsed
                      ? ShellMenu(
                          onOpen: () => controller.toggle(compact: compact),
                          leadingInset: kMacTrafficLightsWidth,
                          child: content,
                        )
                      : content,
                ),
              ),
            ],
          ),
          if (!collapsed)
            Positioned(
              left: controller.width - _handleWidth / 2,
              top: 0,
              bottom: 0,
              width: _handleWidth,
              child: _ResizeHandle(controller: controller),
            ),
          if (compact && controller.overlayOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                key: const Key('mac-sidebar-scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: controller.closeOverlay,
                child: const ColoredBox(color: Color(0x33000000)),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: controller.width,
              child: Material(
                key: const Key('mac-sidebar-overlay'),
                elevation: 16,
                color: context.hermesColors.sidebar,
                child: _SidebarSlot(translucent: false, child: sidebar),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ThemeData _toolbarTheme(BuildContext context, bool collapsed) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        toolbarHeight: kMacToolbarHeight,
        leadingWidth: collapsed ? kMacTrafficLightsWidth + 56 : null,
      ),
    );
  }
}

const double _handleWidth = 8;

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.controller});

  final MacSidebarController controller;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      key: const Key('mac-sidebar-resize'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) =>
          controller.resizeTo(controller.width + details.delta.dx),
      onHorizontalDragEnd: (_) => controller.saveWidth(),
    ),
  );
}
