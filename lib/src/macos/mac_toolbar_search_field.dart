import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../theme/app_icons.dart';
import '../theme/focus_ring.dart';
import '../theme/hermes_theme.dart';
import '../widgets/focusable_tap.dart';

const double _restingWidth = 180;
const double _maxTextScale = 1.3;

/// The room for a line inside the 26 point field and its border.
const double _lineRoom = 22;
const double _fontSize = 13;

/// The line height the theme gives the field's text at the normal size.
const double _themeLineHeight = 1.5;
const double _activeWidth = 240;

/// The search field of a Mac toolbar: a 26pt rounded field that grows from
/// 180 to 240 points with a focus ring while it is in use. Escape and the
/// clear button end the search. Its text stops growing at 1.3 times, so the
/// field stays 26 points at any text size, as a Mac toolbar does.
class MacToolbarSearchField extends StatefulWidget {
  const MacToolbarSearchField({
    super.key,
    required this.query,
    required this.active,
    required this.onChanged,
    required this.onEnd,
    this.onBegin,
    this.onSubmitted,
    this.focusNode,
    this.hint,
    this.fullWidth = false,
  });

  final String query;

  /// Whether a search is open, which keeps the field wide.
  final bool active;
  final ValueChanged<String> onChanged;
  final VoidCallback onEnd;

  /// Called when the field gets the focus, which opens a search.
  final VoidCallback? onBegin;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  /// The placeholder; null reads the localized "Search".
  final String? hint;

  /// Fills the width it is given instead of the toolbar's 180 or 240 points.
  final bool fullWidth;

  @override
  State<MacToolbarSearchField> createState() => _MacToolbarSearchFieldState();
}

class _MacToolbarSearchFieldState extends State<MacToolbarSearchField> {
  late final _text = TextEditingController(text: widget.query);
  FocusNode? _ownFocus;
  final _endFocus = FocusNode(debugLabel: 'MacToolbarSearchField end');
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refocused);
  }

  @override
  void didUpdateWidget(MacToolbarSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_refocused);
      _focus.addListener(_refocused);
    }
    if (widget.query != _text.text) _text.text = widget.query;
  }

  @override
  void dispose() {
    _focus.removeListener(_refocused);
    _ownFocus?.dispose();
    _endFocus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _refocused() {
    if (_focus.hasFocus) widget.onBegin?.call();
    setState(() {});
  }

  void _end() {
    _focus.unfocus();
    // The End button leaves with the search. Focus it held would fall back to
    // the field it was reached from, which would begin a search again, so it
    // goes to the enclosing scope as Escape's does.
    _endFocus.unfocus();
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final focused = _focus.hasFocus;
    final wide = focused || widget.active;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _end},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: widget.fullWidth ? null : (wide ? _activeWidth : _restingWidth),
        height: 26,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: focused
                ? scheme.primary.withValues(alpha: 0.6)
                : scheme.outlineVariant,
            width: focused ? 2 : 1,
          ),
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _maxTextScale,
          child: Builder(
            builder: (context) {
              // The theme's line height, unless a scaled line would not fit.
              final scaled = MediaQuery.textScalerOf(context).scale(_fontSize);
              final fit = _lineRoom / scaled;
              final lineHeight = fit < _themeLineHeight ? fit : null;
              return Row(
                children: [
                  const SizedBox(width: 7),
                  AppIcon(AppIcons.search, size: 14, color: subtle),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TextField(
                      key: const Key('toolbar-search-field'),
                      controller: _text,
                      focusNode: _focus,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: _fontSize, height: lineHeight),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: widget.hint ?? context.l10n.widgetsSearch,
                        hintStyle: TextStyle(
                          fontSize: _fontSize,
                          height: lineHeight,
                          color: subtle,
                        ),
                      ),
                    ),
                  ),
                  if (widget.query.isNotEmpty || widget.active)
                    Semantics(
                      button: true,
                      label: 'End search',
                      // The field's border clips, so the ring sits inside the
                      // button's box, which is as tall as the room for a line.
                      child: FocusRing(
                        radius: 6,
                        child: FocusableTap(
                          focusNode: _endFocus,
                          onActivate: _end,
                          child: GestureDetector(
                            key: const Key('toolbar-search-clear'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _end,
                            child: SizedBox(
                              height: _lineRoom,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Center(
                                  child: AppIcon(
                                    AppIcons.clearFilled,
                                    size: 14,
                                    color: subtle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 7),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
