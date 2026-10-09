import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'adaptive_popup_menu_button.dart';
import 'adaptive_tab_bar.dart';
import 'grouped_list.dart';

/// A labelled value that opens a picker: on iOS the value muted before the
/// chevron, on Material under the label, and on the Mac in a pop-up button.
/// While [busy] it shows progress and ignores taps.
class GroupedValueRow extends StatelessWidget {
  const GroupedValueRow({
    super.key,
    required this.title,
    required this.value,
    this.caption,
    this.warning,
    this.busy = false,
    this.onTap,
  }) : _inMenu = false;

  const GroupedValueRow._inMenu({
    required this.title,
    required this.value,
    this.warning,
  }) : caption = null,
       busy = false,
       onTap = null,
       _inMenu = true;

  final String title;
  final String value;

  /// A muted line under the label, such as the model's provider.
  final String? caption;
  final String? warning;
  final bool busy;
  final VoidCallback? onTap;

  /// Drawn as tappable while the tap goes to the menu button around it.
  final bool _inMenu;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final onTap = busy ? null : this.onTap;
    final enabled = onTap != null || _inMenu;
    final progress = busy
        ? SizedBox.square(
            dimension: chrome == PlatformChrome.macos ? 14 : 18,
            child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : null;
    return switch (chrome) {
      PlatformChrome.material => GroupedRow(
        title: title,
        subtitle: value,
        caption: caption,
        warning: warning,
        trailing: progress,
        chevron: false,
        onTap: onTap,
      ),
      PlatformChrome.macos => GroupedRow(
        title: title,
        caption: caption,
        warning: warning,
        trailing:
            progress ??
            _PopUpValue(value: value, enabled: enabled, onPressed: onTap),
      ),
      // The value stays inside the row's tap target, which a trailing
      // widget beside a tappable GroupedRow would not.
      PlatformChrome.ios => _tappable(
        onTap,
        GroupedRow(
          title: title,
          caption: caption,
          warning: warning,
          // GroupedRow's own value does not shrink for a long one.
          trailing:
              progress ??
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.45,
                ),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: GroupedMetrics.of(context).subtitleSize,
                    color: context.hermesColors.subtleText,
                  ),
                ),
              ),
          chevron: enabled,
        ),
      ),
    };
  }

  static Widget _tappable(VoidCallback? onTap, Widget row) => onTap == null
      ? row
      : MergeSemantics(
          child: Semantics(
            button: true,
            child: InkWell(onTap: onTap, child: row),
          ),
        );
}

/// A Mac pop-up button showing [value].
class _PopUpValue extends StatelessWidget {
  const _PopUpValue({
    required this.value,
    required this.enabled,
    required this.onPressed,
  });

  final String value;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled ? scheme.onSurface : context.hermesColors.subtleText;
    final radius = BorderRadius.circular(6);
    final face = Padding(
      padding: const EdgeInsets.fromLTRB(9, 2, 6, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
          AppIcon(AppIcons.expandMore, size: 12, color: color),
        ],
      ),
    );
    final onPressed = this.onPressed;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outline),
        ),
        child: onPressed == null
            ? face
            : Semantics(
                button: true,
                value: value,
                onTap: onPressed,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onPressed,
                  child: face,
                ),
              ),
      ),
    );
  }
}

/// A [GroupedValueRow] whose tap opens a menu of [options], the [selected]
/// one checked.
class GroupedMenuRow<T> extends StatelessWidget {
  const GroupedMenuRow({
    super.key,
    required this.title,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.placeholder = '',
    this.warning,
  });

  final String title;
  final List<T> options;
  final String Function(T option) labelOf;
  final T? selected;
  final ValueChanged<T> onSelected;

  /// The value shown while nothing is [selected].
  final String placeholder;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    final value = selected == null ? placeholder : labelOf(selected);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: AdaptivePopupMenuButton<T>(
          tooltip: '',
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.under,
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final option in options)
              CheckedPopupMenuItem<T>(
                value: option,
                checked: option == selected,
                child: Text(labelOf(option)),
              ),
          ],
          child: GroupedValueRow._inMenu(
            title: title,
            value: value,
            warning: warning,
          ),
        ),
      ),
    );
  }
}

/// A borderless text field in a group: on Apple platforms a one-line field
/// sits beside its [label] and a longer one shows [hint] (or the label) as
/// its placeholder, as iOS Settings does; on Material the label floats over
/// the text inside the card.
class GroupedTextFieldRow extends StatelessWidget {
  const GroupedTextFieldRow({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.autocorrect = true,
    this.monospace = false,
    this.onChanged,
  }) : assert(controller == null || initialValue == null);

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool autocorrect;
  final bool monospace;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final apple = platformChromeOf(context).isApple;
    final oneLine = maxLines == 1;
    final style = TextStyle(
      fontSize: monospace ? metrics.footerSize : metrics.titleSize,
      fontFamily: monospace ? 'monospace' : null,
      color: scheme.onSurface,
    );
    final hintStyle = TextStyle(fontSize: metrics.titleSize, color: muted);
    final InputDecoration decoration;
    if (apple) {
      decoration = InputDecoration.collapsed(
        hintText: oneLine ? hint : hint ?? label,
        hintStyle: hintStyle,
      ).copyWith(filled: false);
    } else {
      decoration = InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: hintStyle,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          vertical: metrics.rowVerticalPadding,
        ),
      );
    }
    final field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      autocorrect: autocorrect,
      style: style,
      decoration: decoration,
      onChanged: onChanged,
    );
    final Widget content;
    if (apple && oneLine) {
      content = Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: metrics.titleSize,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(width: metrics.leadingGap + 4),
          Expanded(
            child: Semantics(label: label, child: field),
          ),
        ],
      );
    } else if (apple) {
      content = Semantics(label: label, child: field);
    } else {
      content = field;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.rowPadding,
          vertical: apple ? metrics.rowVerticalPadding + 4 : 0,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: content,
        ),
      ),
    );
  }
}

/// A choice between a few [segments] across a group's row: a sliding
/// segmented control on Apple platforms, a [PillSegmentedControl] on
/// Material.
class GroupedSegmentedRow<T extends Object> extends StatelessWidget {
  const GroupedSegmentedRow({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final chrome = platformChromeOf(context);
    final Widget control = chrome.isApple
        ? CupertinoSlidingSegmentedControl<T>(
            groupValue: value,
            backgroundColor: scheme.surfaceContainerHighest,
            thumbColor: scheme.surface,
            padding: const EdgeInsets.all(2),
            children: {
              for (final MapEntry(key: segment, value: label)
                  in segments.entries)
                segment: Semantics(
                  button: true,
                  selected: segment == value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: chrome == PlatformChrome.macos ? 12 : 13,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
            },
            onValueChanged: (segment) {
              if (segment != null) onChanged(segment);
            },
          )
        : PillSegmentedControl<T>(
            value: value,
            segments: segments,
            onChanged: onChanged,
          );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: 8,
      ),
      child: control,
    );
  }
}

/// Why a form could not be saved, in the error colour under its groups.
class GroupedFormError extends StatelessWidget {
  const GroupedFormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        12,
        metrics.rowPadding,
        0,
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: metrics.footerSize,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
