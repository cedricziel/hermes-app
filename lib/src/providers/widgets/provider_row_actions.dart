import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';

/// Whether the selected text size is big enough that a row's buttons move
/// below its text, at full width, instead of sitting beside it.
bool providerLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) > 18.2;

/// A button in or under a provider row: 44 pt tall on iOS, 48 dp on Android
/// and a small 28 pt push button on a Mac. Plain text, or outlined for the
/// row's one stronger action. It is named by [semanticsLabel] when the
/// visible word does not say enough ("Cancel sign-in to ChatGPT").
class ProviderRowButton extends StatelessWidget {
  const ProviderRowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
    this.outlined = false,
    this.fullWidth = false,
  });

  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool fullWidth;

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
    final padding = mac ? const EdgeInsets.symmetric(horizontal: 10) : null;
    final textStyle = mac
        ? Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12)
        : null;
    final child = Text(label, textAlign: TextAlign.center);
    final button = outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              textStyle: textStyle,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: child,
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: size,
              padding: padding,
              textStyle: textStyle,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: child,
          );
    return Semantics(
      button: true,
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
  });

  final GroupedRow Function(Widget? trailing) row;
  final List<Widget> Function(bool stacked) actions;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    if (!providerLargeText(context)) {
      final buttons = actions(false);
      return row(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: buttons,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(null),
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
