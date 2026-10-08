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

/// The search field of a settings page: 36 points with a 10 point radius on
/// iOS, a 44 point pill on Material, and the toolbar search field on macOS.
class SettingsSearchField extends StatefulWidget {
  const SettingsSearchField({super.key, required this.search});

  final SettingsSearch search;

  /// The field's height on iOS or Material.
  static double heightFor({required bool ios}) => ios ? 36 : 44;

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
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          MacToolbarSearchField(
            query: search.query,
            active: search.query.isNotEmpty,
            hint: search.hint,
            onChanged: search.onChanged,
            onEnd: () => search.onChanged(''),
          ),
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
    final height = SettingsSearchField.heightFor(ios: ios);
    final fontSize = ios ? 17.0 : 16.0;
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
                fixedSize: Size.square(height),
                minimumSize: Size.square(height),
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
