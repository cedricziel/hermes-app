import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../context_state.dart';

/// The level the Context row shows for [figures]: neutral below 80%, then
/// nearly full, critical from 95%, and full at 100% or when more is used than
/// the window holds.
ContextLevel contextLevelOf(ContextFigures figures) {
  if (figures.percent >= 100 || figures.used > figures.max) {
    return ContextLevel.full;
  }
  if (figures.percent >= 95) return ContextLevel.critical;
  if (figures.percent >= 80) return ContextLevel.nearlyFull;
  return ContextLevel.normal;
}

/// "124k", "8.4k", "1.2M": the short form for the row's caption.
String contextTokensShort(AppLocalizations l10n, int tokens) {
  final format = NumberFormat('0.#', l10n.localeName);
  if (tokens < 1000) return contextTokensFull(l10n, tokens);
  if (tokens < 10000) {
    return l10n.chatContextTokensThousand(
      format.format((tokens / 100).round() / 10),
    );
  }
  final thousands = (tokens / 1000).round();
  if (thousands < 1000) {
    return l10n.chatContextTokensThousand(thousands.toString());
  }
  return l10n.chatContextTokensMillion(
    format.format((tokens / 100000).round() / 10),
  );
}

/// "124,000": the full count for the details page.
String contextTokensFull(AppLocalizations l10n, int tokens) =>
    NumberFormat.decimalPattern(l10n.localeName).format(tokens);

/// The state word of [level], or null below 80%.
String? contextLevelWord(AppLocalizations l10n, ContextLevel level) =>
    switch (level) {
      ContextLevel.normal => null,
      ContextLevel.nearlyFull ||
      ContextLevel.critical => l10n.chatContextNearlyFull,
      ContextLevel.full => l10n.chatContextFull,
    };

/// The label of the bar for a screen reader.
String contextBarLabel(AppLocalizations l10n, ContextFigures figures) =>
    figures.estimated == true
    ? l10n.chatContextBarLabelEstimated(figures.percent)
    : l10n.chatContextBarLabel(figures.percent);

/// The colour that carries [level]: warning from 80%, error from 95%.
Color? contextLevelColor(BuildContext context, ContextLevel level) =>
    switch (level) {
      ContextLevel.normal => null,
      ContextLevel.nearlyFull => context.hermesColors.warning,
      ContextLevel.critical ||
      ContextLevel.full => Theme.of(context).colorScheme.error,
    };

/// The height of a text button: 48 dp on Material, 44 pt on iOS, 28 pt on a Mac.
double contextTargetHeight(BuildContext context) =>
    switch (platformChromeOf(context)) {
      PlatformChrome.material => 48,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28,
    };

/// Whether text is large enough that rows wrap and buttons stack.
bool contextLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) > 21;

ButtonStyle contextButtonStyle(BuildContext context) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, contextTargetHeight(context))),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// The state word with its icon, from 80%. Words and icon carry the state, the
/// colour only adds to it.
class ContextStateWord extends StatelessWidget {
  const ContextStateWord({super.key, required this.level, this.muted = false});

  final ContextLevel level;

  /// Drawn in the muted colour, as for figures that are not up to date.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final word = contextLevelWord(context.l10n, level);
    if (word == null) return const SizedBox.shrink();
    final color = muted
        ? context.hermesColors.subtleText
        : contextLevelColor(context, level);
    final icon = level == ContextLevel.nearlyFull
        ? AppIcons.warning
        : AppIcons.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: AppIcon(
            icon,
            size: MediaQuery.textScalerOf(context).scale(16),
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            word,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
