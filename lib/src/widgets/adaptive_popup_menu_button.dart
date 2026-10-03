import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

/// Opens an [AdaptivePopupMenuButton]'s menu from outside, for a right-click
/// or a long press on the row the button sits in.
class AdaptiveMenuController {
  VoidCallback? _open;

  void open() => _open?.call();
}

/// A [PopupMenuButton] that follows the platform: a pull-down
/// [CupertinoMenuAnchor] on iOS, a compact Material menu on macOS (rows of
/// 24 logical pixels, as on a Mac), and the plain Material menu elsewhere.
///
/// Takes [PopupMenuEntry] items so call sites read the same on every
/// platform. Items are [PopupMenuItem], [CheckedPopupMenuItem] and
/// [PopupMenuDivider]; anything else does not show on iOS.
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

  static const double macRowHeight = 24;

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

  void _open() {
    if (_popup.currentState case final popup?) {
      popup.showButtonMenu();
    } else if (mounted && platformChromeOf(context) == PlatformChrome.ios) {
      _menu.open();
    }
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

  Widget _material({required bool compact}) => PopupMenuButton<T>(
    key: _popup,
    tooltip: widget.tooltip,
    icon: widget.icon,
    iconSize: widget.iconSize,
    padding: widget.padding,
    style: widget.style,
    offset: widget.offset,
    position: widget.position,
    onSelected: widget.onSelected,
    itemBuilder: compact
        ? (context) => [
            for (final entry in widget.itemBuilder(context)) _compact(entry),
          ]
        : widget.itemBuilder,
    child: widget.child,
  );

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
      height: AdaptivePopupMenuButton.macRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: entry.child,
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
