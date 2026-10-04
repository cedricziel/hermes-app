import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';

const double _restingWidth = 180;
const double _activeWidth = 240;

/// The search field of a Mac toolbar: a 26pt rounded field that grows from
/// 180 to 240 points with a focus ring while it is in use. Escape and the
/// clear button end the search.
class MacToolbarSearchField extends StatefulWidget {
  const MacToolbarSearchField({
    super.key,
    required this.query,
    required this.active,
    required this.onChanged,
    required this.onEnd,
    this.onSubmitted,
    this.focusNode,
  });

  final String query;

  /// Whether a search is open, which keeps the field wide.
  final bool active;
  final ValueChanged<String> onChanged;
  final VoidCallback onEnd;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<MacToolbarSearchField> createState() => _MacToolbarSearchFieldState();
}

class _MacToolbarSearchFieldState extends State<MacToolbarSearchField> {
  late final _text = TextEditingController(text: widget.query);
  FocusNode? _ownFocus;
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
    _text.dispose();
    super.dispose();
  }

  void _refocused() => setState(() {});

  void _end() {
    _focus.unfocus();
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
        width: wide ? _activeWidth : _restingWidth,
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
        child: Row(
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
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search',
                  hintStyle: TextStyle(fontSize: 13, color: subtle),
                ),
              ),
            ),
            if (widget.query.isNotEmpty || widget.active)
              Semantics(
                button: true,
                label: 'End search',
                child: GestureDetector(
                  key: const Key('toolbar-search-clear'),
                  onTap: _end,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AppIcon(
                      AppIcons.clearFilled,
                      size: 14,
                      color: subtle,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 7),
          ],
        ),
      ),
    );
  }
}
