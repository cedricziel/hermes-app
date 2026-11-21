import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../macos/mac_toolbar.dart';
import '../macos/mac_toolbar_search_field.dart';
import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'named_popup_menu_button.dart';

/// One choice of a search's filter menu, such as "Enabled".
class SettingsFilter {
  const SettingsFilter({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
}

/// What a settings page searches: the [query] and its [filters], which a
/// menu button inside the field offers (beside it in a Mac toolbar).
class SettingsSearch {
  const SettingsSearch({
    required this.query,
    required this.onChanged,
    this.hint = 'Search',
    this.filters = const [],
  });

  final String query;
  final ValueChanged<String> onChanged;
  final String hint;

  /// The filter menu's choices, the first being the one that shows
  /// everything ("All").
  final List<SettingsFilter> filters;

  /// Whether a filter narrows the list, which marks the filter button.
  bool get filterActive => filters.isNotEmpty && !filters.first.selected;
}

/// The search field of a settings page: 36 points (more at large text) with a 10 point radius on
/// iOS, a 44 point pill on Material, and the toolbar search field on macOS.
class SettingsSearchField extends StatefulWidget {
  const SettingsSearchField({
    super.key,
    required this.search,
    this.fullWidth = false,
  });

  final SettingsSearch search;

  /// On a Mac, fills the width it is given instead of the toolbar's size.
  final bool fullWidth;

  /// The field's height on iOS or Material: 36 or 44 points, or taller when
  /// the text at [textScaler] needs more room for one line and its padding.
  static double heightFor({
    required bool ios,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final needed = textScaler.scale(_fontSize(ios)) * _lineHeight + _padding;
    return math.max(ios ? 36.0 : 44.0, needed);
  }

  static double _fontSize(bool ios) => ios ? 17 : 16;

  /// The body line height of the theme's text styles, as a multiple of the
  /// font size.
  static const _lineHeight = 1.5;

  /// Room above and below the line at its tallest.
  static const _padding = 8.0;

  @override
  State<SettingsSearchField> createState() => _SettingsSearchFieldState();
}

class _SettingsSearchFieldState extends State<SettingsSearchField> {
  late final _text = TextEditingController(text: widget.search.query);

  @override
  void didUpdateWidget(SettingsSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.search.query != _text.text) _text.text = widget.search.query;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.search;
    final chrome = platformChromeOf(context);
    if (chrome == PlatformChrome.macos) {
      final field = MacToolbarSearchField(
        fullWidth: widget.fullWidth,
        query: search.query,
        active: search.query.isNotEmpty,
        hint: search.hint,
        onChanged: search.onChanged,
        onEnd: () => search.onChanged(''),
      );
      return Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        spacing: 4,
        children: [
          if (widget.fullWidth) Expanded(child: field) else field,
          if (search.filters.isNotEmpty)
            MacToolbarMenu<VoidCallback>(
              key: const Key('settings-search-filter'),
              label: 'Filter',
              icon: AppIcons.filter,
              selected: search.filterActive,
              itemBuilder: _filterItems,
              onSelected: _run,
            ),
        ],
      );
    }
    final ios = chrome == PlatformChrome.ios;
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final height = SettingsSearchField.heightFor(
      ios: ios,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final fontSize = SettingsSearchField._fontSize(ios);
    // The filter button keeps its platform size however tall the field gets.
    final buttonSize = SettingsSearchField.heightFor(ios: ios);
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest,
        shape: ios
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            : const StadiumBorder(),
      ),
      padding: EdgeInsets.only(left: ios ? 8 : 16),
      child: Row(
        children: [
          AppIcon(AppIcons.search, size: ios ? 18 : 22, color: muted),
          SizedBox(width: ios ? 6 : 12),
          Expanded(
            // The placeholder is gone once there is text, so the field is
            // named explicitly.
            child: Semantics(
              label: search.hint,
              child: TextField(
                key: const Key('settings-search-field'),
                controller: _text,
                onChanged: search.onChanged,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(fontSize: fontSize),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: search.hint,
                  hintStyle: TextStyle(fontSize: fontSize, color: muted),
                ),
              ),
            ),
          ),
          if (search.query.isNotEmpty)
            Semantics(
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                key: const Key('settings-search-clear'),
                behavior: HitTestBehavior.opaque,
                onTap: () => search.onChanged(''),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AppIcon(
                    AppIcons.clearFilled,
                    size: ios ? 16 : 20,
                    color: muted,
                  ),
                ),
              ),
            ),
          if (search.filters.isNotEmpty)
            NamedPopupMenuButton<VoidCallback>(
              key: const Key('settings-search-filter'),
              label: 'Filter',
              icon: AppIcons.filter,
              color: search.filterActive ? scheme.onSurface : muted,
              iconSize: ios ? 18 : 22,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                fixedSize: Size.square(buttonSize),
                minimumSize: Size.square(buttonSize),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: search.filterActive
                    ? scheme.onSurface.withValues(alpha: 0.08)
                    : null,
              ),
              itemBuilder: _filterItems,
              onSelected: _run,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  List<PopupMenuEntry<VoidCallback>> _filterItems(BuildContext context) => [
    for (final filter in widget.search.filters)
      CheckedPopupMenuItem<VoidCallback>(
        value: filter.onSelected,
        checked: filter.selected,
        child: Text(filter.label),
      ),
  ];

  static void _run(VoidCallback action) => action();
}
