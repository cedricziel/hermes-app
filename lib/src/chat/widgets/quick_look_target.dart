import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../drag_out/mac_drag_out_source.dart' show dragOutSlop;
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_popup_menu_button.dart';

/// Whether attachments follow Finder's model here: click to select,
/// double-click to open, Space to preview. Only on macOS.
bool quickLookTargetsAt(BuildContext context) =>
    platformChromeOf(context) == PlatformChrome.macos;

/// Makes an attachment behave like a Finder item on macOS, and is [child]
/// unchanged elsewhere.
///
/// A single click selects it, a double-click runs [onOpen], and while it is
/// selected Space runs [onToggle] and Enter runs [onOpen]. A secondary click
/// selects it and opens a menu with Quick Look ([onShow]), Open ([onOpen])
/// and Save… ([onSave]); an item whose callback is null is disabled.
///
/// Selected means focused: the target owns one [FocusNode], so only one
/// target is selected at a time, a text field taking focus ends the
/// selection (and a space typed there stays a space), and Tab reaches it. A
/// click outside it clears it.
///
/// A press that moves as far as a drag-out starts after is a drag, not a
/// click, so dragging an attachment out of the app never opens it. Clicks on
/// controls inside [child] (a Save button) do not count as clicks on the
/// target, and nothing here delays them.
class QuickLookTarget extends StatefulWidget {
  const QuickLookTarget({
    super.key,
    required this.child,
    this.onOpen,
    this.onToggle,
    this.onShow,
    this.onSave,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;

  /// Double-click, Enter, the menu's Open and a screen reader's activation.
  final VoidCallback? onOpen;

  /// Space: show the preview, or close it when it already shows this file.
  final VoidCallback? onToggle;

  /// The menu's Quick Look: show the preview.
  final VoidCallback? onShow;

  /// The menu's Save….
  final VoidCallback? onSave;

  /// The corners of the selection's outline.
  final BorderRadius borderRadius;

  @override
  State<QuickLookTarget> createState() => _QuickLookTargetState();
}

class _QuickLookTargetState extends State<QuickLookTarget> {
  final _node = FocusNode(debugLabel: 'QuickLookTarget');
  final _menu = AdaptiveMenuController();
  var _selected = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // A control inside has the focus: Space and Enter are its to press.
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.space) {
      final toggle = widget.onToggle;
      if (toggle == null ||
          keyboard.isMetaPressed ||
          keyboard.isControlPressed ||
          keyboard.isAltPressed) {
        return KeyEventResult.ignored;
      }
      // Only the first press acts; a held key neither repeats the toggle nor
      // scrolls the list.
      if (event is KeyDownEvent) toggle();
      return KeyEventResult.handled;
    }
    final open = widget.onOpen;
    if (open != null &&
        event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      open();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _outside(PointerDownEvent event) {
    // A menu or dialog over the target is not the chat background: choosing
    // from the menu must not end the selection it was opened for.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    // Late, so that a press on another target, which asks for focus in the
    // same event, is applied first and is not undone by this one.
    scheduleMicrotask(() {
      if (mounted && _node.hasFocus) _node.unfocus();
    });
  }

  /// A menu or dialog taking focus does not end the selection; it comes back
  /// when that closes.
  void _focusChanged(bool focused) {
    final covered = ModalRoute.of(context)?.isCurrent == false;
    setState(() => _selected = focused || (_selected && covered));
  }

  List<PopupMenuEntry<void>> _items(BuildContext context) => [
    AdaptiveMenuItem<void>(
      onTap: widget.onShow,
      enabled: widget.onShow != null,
      shortcut: 'Space',
      child: const Text('Quick Look'),
    ),
    AdaptiveMenuItem<void>(
      onTap: widget.onOpen,
      enabled: widget.onOpen != null,
      shortcut: 'Double-click',
      child: const Text('Open'),
    ),
    AdaptiveMenuItem<void>(
      onTap: widget.onSave,
      enabled: widget.onSave != null,
      child: const Text('Save…'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!quickLookTargetsAt(context)) return widget.child;
    return TapRegion(
      // Only the selected target has anything to do on a click elsewhere.
      enabled: _selected,
      onTapOutside: _outside,
      child: Focus(
        focusNode: _node,
        onKeyEvent: _onKey,
        onFocusChange: _focusChanged,
        child: RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            _ClickRecognizer:
                GestureRecognizerFactoryWithHandlers<_ClickRecognizer>(
                  _ClickRecognizer.new,
                  (recognizer) {
                    recognizer
                      ..onDown = _node.requestFocus
                      ..onDoubleClick = widget.onOpen
                      ..onSecondaryClick = (at) => _menu.open(at: at);
                  },
                ),
          },
          child: Semantics(
            selected: _selected,
            onTap: widget.onOpen,
            child: QuickLookSelectionFrame(
              selected: _selected,
              borderRadius: widget.borderRadius,
              child: Stack(
                fit: StackFit.passthrough,
                clipBehavior: Clip.none,
                children: [
                  widget.child,
                  // The anchor of the context menu, which has no button of
                  // its own to open from.
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 0,
                    height: 0,
                    child: ExcludeFocus(
                      child: ExcludeSemantics(
                        child: AdaptivePopupMenuButton<void>(
                          controller: _menu,
                          tooltip: '',
                          itemBuilder: _items,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the selection of a [QuickLookTarget]: an outline and a fill, so it
/// does not rest on colour alone. Takes up no room and keeps [child] where it
/// is, selected or not.
class QuickLookSelectionFrame extends StatelessWidget {
  const QuickLookSelectionFrame({
    super.key,
    required this.selected,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final bool selected;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: selected ? primary.withValues(alpha: 0.08) : null,
        border: selected ? Border.all(color: primary, width: 2) : null,
      ),
      child: child,
    );
  }
}

/// Sees a press and a release of the primary or secondary button as a click,
/// unless the pointer moved as far as a drag-out starts after, and two primary
/// clicks close together as a double-click.
///
/// It never claims a gesture and holds no arena, so a control under it keeps
/// its own taps and loses nothing to a wait for a second click: when another
/// recognizer takes the press, this one is rejected and the clicks it counted
/// are forgotten. It does win a press that nothing else claims, and then acts
/// on release.
class _ClickRecognizer extends OneSequenceGestureRecognizer {
  /// The pointer went down on the target, whoever gets the click.
  VoidCallback? onDown;
  VoidCallback? onDoubleClick;
  ValueChanged<Offset>? onSecondaryClick;

  int? _pointer;
  var _origin = Offset.zero;
  var _moved = false;
  var _secondary = false;
  var _accepted = false;
  Offset? _released;

  Timer? _window;
  Offset? _firstClick;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      (event.buttons == kPrimaryButton || event.buttons == kSecondaryButton) &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _origin = event.position;
    _secondary = event.buttons == kSecondaryButton;
    _moved = false;
    _accepted = false;
    _released = null;
    startTrackingPointer(event.pointer, event.transform);
    onDown?.call();
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      if ((event.position - _origin).distance >= dragOutSlop) _moved = true;
    } else if (event is PointerUpEvent) {
      _released = event.position;
      if (_accepted) _click();
    } else if (event is PointerCancelEvent) {
      _end(forget: true);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer) return;
    _accepted = true;
    if (_released != null) _click();
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _end(forget: true);
  }

  void _click() {
    final at = _released;
    final moved = _moved;
    final secondary = _secondary;
    _end(forget: moved);
    if (at == null || moved) return;
    if (secondary) {
      onSecondaryClick?.call(at);
      return;
    }
    final first = _firstClick;
    if (_window?.isActive == true &&
        first != null &&
        (at - first).distance < kDoubleTapSlop) {
      _forget();
      onDoubleClick?.call();
    } else {
      _firstClick = at;
      _window?.cancel();
      _window = Timer(kDoubleTapTimeout, _forget);
    }
  }

  void _end({required bool forget}) {
    final pointer = _pointer;
    _pointer = null;
    _released = null;
    if (pointer != null) stopTrackingPointer(pointer);
    if (forget) _forget();
  }

  void _forget() {
    _window?.cancel();
    _window = null;
    _firstClick = null;
  }

  @override
  void dispose() {
    _window?.cancel();
    super.dispose();
  }

  @override
  String get debugDescription => 'click';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
