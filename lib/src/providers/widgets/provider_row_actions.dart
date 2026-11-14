import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';

/// Whether the selected text size is big enough that a row's buttons move
/// below its text, at full width, instead of sitting beside it.
bool providerLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) > 18.2;

/// A button in or under a provider row, or in a form or step: 44 pt tall on
/// iOS, 48 dp on Android and a small 28 pt push button on a Mac. Plain text,
/// outlined for the row's one stronger action, or [filled] for the one
/// primary action of a form or step. It is named by [semanticsLabel] when the
/// visible word does not say enough ("Cancel sign-in to ChatGPT").
class ProviderRowButton extends StatelessWidget {
  const ProviderRowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
    this.outlined = false,
    this.filled = false,
    this.fullWidth = false,
    this.autofocus = false,
    this.focusNode,
    this.liveRegion = false,
  });

  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool filled;
  final bool fullWidth;
  final bool autofocus;
  final FocusNode? focusNode;

  /// The label is announced when it changes ("Code copied").
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final mac = chrome == PlatformChrome.macos;
    final height = switch (chrome) {
      PlatformChrome.material => 48.0,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
    };
    final size = Size(fullWidth ? double.infinity : (mac ? 0 : height), height);
    final padding = mac
        ? const EdgeInsets.symmetric(horizontal: 10)
        : EdgeInsets.symmetric(horizontal: outlined ? 16 : 12, vertical: 8);
    final textStyle = mac
        ? Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12)
        : null;
    final child = Text(label, textAlign: TextAlign.center);
    final button = filled
        ? FilledButton(
            onPressed: onPressed,
            autofocus: autofocus,
            focusNode: focusNode,
            style: FilledButton.styleFrom(
              minimumSize: size,
              padding: padding,
              textStyle: textStyle,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
            child: child,
          )
        : outlined
        ? OutlinedButton(
            onPressed: onPressed,
            autofocus: autofocus,
            focusNode: focusNode,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              textStyle: textStyle,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
            child: child,
          )
        : TextButton(
            onPressed: onPressed,
            autofocus: autofocus,
            focusNode: focusNode,
            style: TextButton.styleFrom(
              minimumSize: size,
              padding: padding,
              textStyle: textStyle,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
            child: child,
          );
    return Semantics(
      container: true,
      button: true,
      liveRegion: liveRegion,
      enabled: onPressed != null,
      label: semanticsLabel ?? label,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// A [GroupedRow] with buttons: beside the text at the default size, below it
/// at full width at a large one. [row] builds the row with the trailing
/// widget it is given (null when the buttons sit below). [actions] builds the
/// buttons for the layout in use, so the stacked order can differ (Continue
/// first).
class ProviderActionRow extends StatelessWidget {
  const ProviderActionRow({
    super.key,
    required this.row,
    required this.actions,
    this.textLabel,
  });

  final GroupedRow Function(Widget? trailing) row;
  final List<Widget> Function(bool stacked) actions;

  /// What a screen reader says for the text beside the buttons, when the
  /// visible words need spelling out (a key's last four characters).
  final String? textLabel;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final label = textLabel;
    Widget text() => label == null
        ? row(null)
        : Semantics(
            container: true,
            label: label,
            excludeSemantics: true,
            child: row(null),
          );
    if (!providerLargeText(context)) {
      final buttons = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: actions(false),
        ),
      );
      if (label == null) return row(buttons);
      return Row(
        children: [
          Expanded(child: text()),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: 8,
              end: metrics.rowPadding,
            ),
            child: buttons,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            0,
            metrics.rowPadding,
            metrics.rowVerticalPadding + 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: actions(true),
          ),
        ),
      ],
    );
  }
}
