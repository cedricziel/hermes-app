import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_window_utils/widgets/transparent_macos_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shell/shell_navigation.dart';
import '../theme/app_icons.dart';
import 'mac_toolbar.dart';
import 'mac_window.dart';

const double kMacSidebarMinWidth = 220;
const double kMacSidebarMaxWidth = 360;
const double kMacSidebarDefaultWidth = 280;

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

  void toggle() {
    _touched = true;
    _collapsed = !_collapsed;
    notifyListeners();
    _prefs.setBool(_collapsedKey, _collapsed);
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

/// Owns the [MacSidebarController] for a Mac window and binds Control-Command-S,
/// the system's shortcut for showing and hiding a sidebar.
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

  /// The folded sections of the sidebar above [context], without rebuilding
  /// [context] when the sidebar is resized or hidden.
  static MacSidebarSections? sectionsOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_ControllerScope>()
      ?.notifier
      ?.sections;

  @override
  State<MacSidebarScope> createState() => _MacSidebarScopeState();
}

class _MacSidebarScopeState extends State<MacSidebarScope> {
  late final _controller = widget.controller ?? MacSidebarController();

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _controller.load();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey != LogicalKeyboardKey.keyS ||
        !keyboard.isControlPressed ||
        !keyboard.isMetaPressed) {
      return false;
    }
    _controller.toggle();
    return true;
  }

  @override
  Widget build(BuildContext context) =>
      _ControllerScope(notifier: _controller, child: widget.child);
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
  Widget build(BuildContext context) => MacToolbarButton(
    key: const Key('mac-sidebar-toggle'),
    label: controller.collapsed ? 'Show sidebar' : 'Hide sidebar',
    shortcut: '⌃⌘S',
    icon: AppIcons.sidebar,
    onPressed: controller.toggle,
  );
}

/// A sidebar beside its content, as in a Mac app: the sidebar sits on the
/// system's sidebar material behind the traffic lights, can be dragged wider
/// or narrower and can be hidden. Without a [MacSidebarScope] it is a fixed
/// column.
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
    final collapsed = controller.collapsed;
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
                          onOpen: controller.toggle,
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
