import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

/// Opens an [AdaptivePopupMenuButton]'s menu from outside, for a right-click
/// or a long press on the row the button sits in.
class AdaptiveMenuController {
  void Function(Offset? at)? _open;

  /// Opens the menu at its button, or on macOS [at] a global position, as a
  /// Mac context menu opens under the pointer.
  void open({Offset? at}) => _open?.call(at);
}

/// A [PopupMenuItem] with what a Mac menu shows besides its label: the
/// keyboard [shortcut], right-aligned and muted (macOS only), and whether it
/// is [destructive], in the error colour.
class AdaptiveMenuItem<T> extends PopupMenuItem<T> {
  const AdaptiveMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    this.shortcut,
    this.destructive = false,
    this.macHeight,
    required super.child,
  });

  /// The shortcut as a Mac menu writes it, such as `⇧⌘P`.
  final String? shortcut;
  final bool destructive;

  /// The row's height in a Mac menu, for an item of two lines; one line of
  /// [AdaptivePopupMenuButton.macRowHeight] when null.
  final double? macHeight;
}

/// A [PopupMenuButton] that follows the platform: a pull-down
/// [CupertinoMenuAnchor] on iOS, a compact menu on macOS (rows of 22 logical
/// pixels highlighted in the primary colour, as on a Mac), and the plain
/// Material menu elsewhere.
///
/// Takes [PopupMenuEntry] items so call sites read the same on every
/// platform. Items are [PopupMenuItem], [AdaptiveMenuItem],
/// [CheckedPopupMenuItem] and [PopupMenuDivider]; anything else does not show
/// on iOS.
class AdaptivePopupMenuButton<T> extends StatefulWidget {
  const AdaptivePopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.icon,
    this.child,
    this.tooltip,
    this.padding = const EdgeInsets.all(8),
    this.iconSize,
    this.style,
    this.offset = Offset.zero,
    this.position,
    this.controller,
  }) : assert(icon == null || child == null);

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget? icon;
  final Widget? child;

  /// Hover text; an empty string adds none. Null keeps Material's default.
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final double? iconSize;
  final ButtonStyle? style;
  final Offset offset;
  final PopupMenuPosition? position;
  final AdaptiveMenuController? controller;

  static const double macRowHeight = 22;

  @override
  State<AdaptivePopupMenuButton<T>> createState() =>
      _AdaptivePopupMenuButtonState<T>();
}

class _AdaptivePopupMenuButtonState<T>
    extends State<AdaptivePopupMenuButton<T>> {
  final _popup = GlobalKey<PopupMenuButtonState<T>>();
  final _menu = MenuController();

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(AdaptivePopupMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._open = null;
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller?._open = null;
    super.dispose();
  }

  void _attach(AdaptiveMenuController? controller) {
    controller?._open = _open;
  }

  /// A menu opens under the pointer only on macOS; elsewhere at its button.
  void _open(Offset? at) {
    if (!mounted) return;
    final chrome = platformChromeOf(context);
    final popup = _popup.currentState;
    if (popup == null) {
      if (chrome == PlatformChrome.ios) _menu.open();
    } else if (at != null && chrome == PlatformChrome.macos) {
      _openAt(popup.context, at);
    } else {
      popup.showButtonMenu();
    }
  }

  /// [context] is the popup button's, under the menu theme it carries.
  Future<void> _openAt(BuildContext context, Offset at) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final point = overlay.globalToLocal(at);
    final value = await showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        point & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: _items(context),
    );
    if (value != null && mounted) widget.onSelected?.call(value);
  }

  void _select(PopupMenuItem<T> item) {
    item.onTap?.call();
    final value = item.value;
    if (value != null) widget.onSelected?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return switch (platformChromeOf(context)) {
      PlatformChrome.ios => _pullDown(context),
      PlatformChrome.macos => _material(compact: true),
      PlatformChrome.material => _material(compact: false),
    };
  }

  Widget _material({required bool compact}) {
    final button = PopupMenuButton<T>(
      key: _popup,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      padding: widget.padding,
      style: widget.style,
      offset: widget.offset,
      position: widget.position,
      onSelected: widget.onSelected,
      itemBuilder: _items,
      child: widget.child,
    );
    if (!compact) return button;
    // The rows paint their own highlight; Material's would show around it.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: button,
    );
  }

  List<PopupMenuEntry<T>> _items(BuildContext context) {
    final compact = platformChromeOf(context) == PlatformChrome.macos;
    return [
      for (final entry in widget.itemBuilder(context))
        compact ? _compact(entry) : _plain(entry),
    ];
  }

  PopupMenuEntry<T> _plain(PopupMenuEntry<T> entry) => switch (entry) {
    AdaptiveMenuItem<T>(destructive: true) => PopupMenuItem<T>(
      value: entry.value,
      onTap: entry.onTap,
      enabled: entry.enabled,
      child: Builder(
        builder: (context) => DefaultTextStyle.merge(
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          child: entry.child ?? const SizedBox.shrink(),
        ),
      ),
    ),
    _ => entry,
  };

  static double _macHeight(PopupMenuItem<Object?> entry) =>
      (entry is AdaptiveMenuItem ? entry.macHeight : null) ??
      AdaptivePopupMenuButton.macRowHeight;

  PopupMenuEntry<T> _compact(PopupMenuEntry<T> entry) => switch (entry) {
    CheckedPopupMenuItem<T>() => CheckedPopupMenuItem<T>(
      value: entry.value,
      checked: entry.checked,
      enabled: entry.enabled,
      height: AdaptivePopupMenuButton.macRowHeight,
      child: entry.child,
    ),
    PopupMenuItem<T>() => PopupMenuItem<T>(
      value: entry.value,
      onTap: entry.onTap,
      enabled: entry.enabled,
      height: _macHeight(entry),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: MacMenuRow(
        height: _macHeight(entry),
        enabled: entry.enabled,
        shortcut: entry is AdaptiveMenuItem<T> ? entry.shortcut : null,
        destructive: entry is AdaptiveMenuItem<T> && entry.destructive,
        child: entry.child ?? const SizedBox.shrink(),
      ),
    ),
    PopupMenuDivider() => const PopupMenuDivider(height: 9),
    _ => entry,
  };

  Widget _pullDown(BuildContext context) {
    final label = widget.tooltip;
    final trigger = widget.child;
    final icon = widget.icon;
    return CupertinoMenuAnchor(
      controller: _menu,
      menuChildren: [
        for (final entry in widget.itemBuilder(context))
          switch (entry) {
            PopupMenuDivider() => const CupertinoMenuDivider(),
            CheckedPopupMenuItem<T>() => CupertinoMenuItem(
              onPressed: entry.enabled ? () => _select(entry) : null,
              trailing: entry.checked
                  ? const Icon(CupertinoIcons.checkmark, size: 18)
                  : null,
              child: entry.child ?? const SizedBox.shrink(),
            ),
            PopupMenuItem<T>() => CupertinoMenuItem(
              onPressed: entry.enabled ? () => _select(entry) : null,
              isDestructiveAction:
                  entry is AdaptiveMenuItem<T> && entry.destructive,
              child: entry.child ?? const SizedBox.shrink(),
            ),
            _ => const SizedBox.shrink(),
          },
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        final Widget button = trigger != null
            ? Semantics(
                button: true,
                onTap: toggle,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: toggle,
                  child: trigger,
                ),
              )
            : IconButton(
                onPressed: toggle,
                icon: icon ?? const Icon(CupertinoIcons.ellipsis),
                iconSize: widget.iconSize,
                padding: widget.padding,
                style: widget.style,
              );
        return label == null || label.isEmpty
            ? button
            : Tooltip(message: label, child: button);
      },
    );
  }
}

/// A row whose menu also opens on a right-click, as on a Mac. [builder]
/// puts the controller on the row's [AdaptivePopupMenuButton].
class ContextMenuRow extends StatefulWidget {
  const ContextMenuRow({super.key, required this.builder});

  final Widget Function(BuildContext context, AdaptiveMenuController menu)
  builder;

  @override
  State<ContextMenuRow> createState() => _ContextMenuRowState();
}

class _ContextMenuRowState extends State<ContextMenuRow> {
  final _menu = AdaptiveMenuController();

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onSecondaryTapUp: (details) => _menu.open(at: details.globalPosition),
    child: widget.builder(context, _menu),
  );
}

/// One row of a Mac menu: highlighted in the primary colour under the pointer
/// or keyboard focus, with its shortcut right-aligned and muted.
class MacMenuRow extends StatefulWidget {
  const MacMenuRow({
    super.key,
    required this.child,
    this.shortcut,
    this.destructive = false,
    this.enabled = true,
    this.height = AdaptivePopupMenuButton.macRowHeight,
  });

  final Widget child;
  final String? shortcut;
  final bool destructive;
  final bool enabled;
  final double height;

  @override
  State<MacMenuRow> createState() => _MacMenuRowState();
}

class _MacMenuRowState extends State<MacMenuRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = Focus.maybeOf(context)?.hasFocus ?? false;
    final lit = widget.enabled && (_hovered || focused);
    final muted = scheme.onSurface.withValues(alpha: 0.45);
    final color = lit
        ? scheme.onPrimary
        : !widget.enabled
        ? muted
        : widget.destructive
        ? scheme.error
        : scheme.onSurface;
    final shortcut = widget.shortcut;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: lit ? scheme.primary : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: 13, color: color),
          child: Row(
            children: [
              Expanded(child: widget.child),
              if (shortcut != null) ...[
                const SizedBox(width: 24),
                Text(
                  shortcut,
                  style: TextStyle(
                    color: lit
                        ? scheme.onPrimary.withValues(alpha: 0.8)
                        : muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
