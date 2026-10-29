import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../input/screen_gesture_layer.dart';

/// The row of keys a touch device shows while in control: the keys a phone's
/// keyboard has no room for (Esc, Tab, the arrows), Ctrl and Alt, which latch
/// for the next key, the keyboard itself, Paste and the Touch or Trackpad
/// switch. It scrolls sideways on a narrow screen.
///
/// It draws what it is given and holds no state: [ctrl] and [alt] say whether
/// a modifier is latched, [keyboardOpen] whether the on-screen keyboard is
/// shown.
class BotScreenKeyBar extends StatelessWidget {
  const BotScreenKeyBar({
    super.key,
    required this.mode,
    required this.ctrl,
    required this.alt,
    required this.keyboardOpen,
    required this.onMode,
    required this.onEscape,
    required this.onTab,
    required this.onLeft,
    required this.onRight,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.onToggleKeyboard,
    required this.onPaste,
  });

  final ScreenGestureMode mode;
  final bool ctrl;
  final bool alt;
  final bool keyboardOpen;
  final ValueChanged<ScreenGestureMode> onMode;
  final VoidCallback onEscape;
  final VoidCallback onTab;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final trackpad = mode == ScreenGestureMode.trackpad;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          _Key.icon(
            icon: AppIcons.keyboard,
            label: 'Keyboard',
            latched: keyboardOpen,
            onPressed: onToggleKeyboard,
          ),
          const _Gap(),
          _Key.text(label: 'Esc', onPressed: onEscape),
          const _Gap(),
          _Key.text(label: 'Tab', onPressed: onTab),
          const _Gap(),
          _Key.text(label: 'Ctrl', latched: ctrl, onPressed: onToggleCtrl),
          const _Gap(),
          _Key.text(label: 'Alt', latched: alt, onPressed: onToggleAlt),
          const _Gap(),
          _Key.icon(
            icon: AppIcons.chevronLeft,
            label: 'Left arrow',
            onPressed: onLeft,
          ),
          const _Gap(),
          _Key.icon(
            icon: AppIcons.chevronRight,
            label: 'Right arrow',
            onPressed: onRight,
          ),
          const _Gap(),
          _Key.icon(icon: AppIcons.paste, label: 'Paste', onPressed: onPaste),
          const _Gap(),
          _Key.icon(
            icon: trackpad ? AppIcons.pointer : AppIcons.touch,
            label: trackpad ? 'Use Touch mode' : 'Use Trackpad mode',
            onPressed: () => onMode(
              trackpad ? ScreenGestureMode.touch : ScreenGestureMode.trackpad,
            ),
          ),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 4);
}

/// One key of the bar. A key with [latched] set is a toggle and draws as held.
class _Key extends StatelessWidget {
  const _Key.text({
    required String this.label,
    this.latched,
    required this.onPressed,
  }) : icon = null,
       tooltip = null;

  const _Key.icon({
    required AppIconSet this.icon,
    required String label,
    this.latched,
    required this.onPressed,
  }) : label = null,
       tooltip = label;

  final String? label;
  final AppIconSet? icon;

  /// The accessible name of an icon key, which is its tooltip as well.
  final String? tooltip;

  /// Null for a key that only taps; whether a toggle is on otherwise.
  final bool? latched;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final held = latched ?? false;
    final minimum = platformChromeOf(context) == PlatformChrome.ios
        ? 44.0
        : 40.0;
    final foreground = held ? scheme.onPrimary : scheme.onSurface;
    final content = label != null
        ? Text(
            label!,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          )
        : AppIcon(icon!, size: 20, color: foreground);
    final key = Material(
      color: held ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 38, minHeight: minimum),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: content,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      toggled: latched,
      label: label ?? tooltip,
      excludeSemantics: true,
      onTap: onPressed,
      child: tooltip == null
          ? key
          : Tooltip(message: tooltip!, excludeFromSemantics: true, child: key),
    );
  }
}
