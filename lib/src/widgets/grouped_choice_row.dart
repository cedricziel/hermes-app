import 'package:material_ui/material_ui.dart';

import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'grouped_list.dart';

/// The width of a shrink-wrapped Material radio button.
const _radioSize = 40.0;

/// One option of a choice in a [GroupedSection]: a check mark at the trailing
/// edge on Apple platforms, a radio button at the leading edge on Material.
///
/// The rows of one choice sit under a [RadioGroup] of [T], which holds the
/// picked value and is told when a row is tapped. The section passes
/// [GroupedChoiceRow.dividerIndent] so separators start past the radio.
class GroupedChoiceRow<T> extends StatelessWidget {
  const GroupedChoiceRow({
    super.key,
    required this.value,
    required this.title,
    this.titleMaxLines = 1,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.titleMiddleEllipsis = false,
    this.subtitleMiddleEllipsis = false,
    this.meta,
    this.warning,
    this.details = const [],
    this.enabled = true,
    this.autofocus = false,
    this.rowFocusable = true,
    this.focusNode,
  });

  final T value;
  final String title;
  final int? titleMaxLines;
  final String? subtitle;

  /// How many lines the [subtitle] may take; null lets it wrap in full.
  final int? subtitleMaxLines;

  /// Cut the title or the subtitle in the middle, for an identifier. See
  /// [GroupedRow.titleMiddleEllipsis].
  final bool titleMiddleEllipsis;
  final bool subtitleMiddleEllipsis;
  final String? meta;
  final String? warning;

  /// Widgets under the subtitle, such as a path cut in the middle.
  final List<Widget> details;
  final bool enabled;

  /// Takes the keyboard focus when it is built, for the checked row of a
  /// popover.
  final bool autofocus;

  /// Whether the row's own tap target is a second keyboard stop beside the
  /// radio. Off in a popover, where the arrows walk the rows and, with a
  /// [focusNode], the focus is drawn across the row.
  final bool rowFocusable;

  /// The radio's focus node, for a caller that moves focus between rows.
  final FocusNode? focusNode;

  /// Where the separators of a group of choice rows start: past the radio
  /// button on Material, at the text on Apple platforms.
  static double? dividerIndent(BuildContext context) {
    if (platformChromeOf(context).isApple) return null;
    final metrics = GroupedMetrics.of(context);
    return metrics.rowPadding + _radioSize + metrics.leadingGap;
  }

  @override
  Widget build(BuildContext context) {
    final apple = platformChromeOf(context).isApple;
    final group = RadioGroup.maybeOf<T>(context);
    final radio = Radio<T>.adaptive(
      value: value,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      // The popover draws its own outline across the row.
      focusColor: rowFocusable ? null : Colors.transparent,
      useCupertinoCheckmarkStyle: true,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final row = GroupedRow(
      title: title,
      titleMaxLines: titleMaxLines,
      subtitle: subtitle,
      subtitleMaxLines: subtitleMaxLines,
      titleMiddleEllipsis: titleMiddleEllipsis,
      subtitleMiddleEllipsis: subtitleMiddleEllipsis,
      meta: meta,
      warning: warning,
      details: details,
      leading: apple ? null : radio,
      trailing: apple ? radio : null,
      chevron: false,
      focusable: rowFocusable,
      focusFill: rowFocusable,
      checked: group?.groupValue == value,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      onTap: group == null ? null : () => group.onChanged(value),
    );
    return rowFocusable ? row : _FocusOutline(child: row);
  }
}

/// A 2 px outline in the link colour, radius 10, around [child] while the
/// keyboard has focus inside it: the focus mark of a popover row, which the
/// arrow keys walk. Nothing is drawn for a pointer.
class _FocusOutline extends StatefulWidget {
  const _FocusOutline({required this.child});

  final Widget child;

  @override
  State<_FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<_FocusOutline> {
  bool _focused = false;
  bool _keyboard = false;

  @override
  void initState() {
    super.initState();
    _keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    FocusManager.instance.addHighlightModeListener(_modeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged(FocusHighlightMode mode) =>
      setState(() => _keyboard = mode == FocusHighlightMode.traditional);

  @override
  Widget build(BuildContext context) {
    final outline = _focused && _keyboard;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: outline
              ? Border.all(color: context.hermesColors.link, width: 2)
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
