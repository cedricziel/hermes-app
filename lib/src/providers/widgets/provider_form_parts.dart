import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import 'provider_row_actions.dart';

/// The buttons of a form or a step: stacked at full width, the primary one
/// first, on a phone and at a large text size. A Mac window right-aligns
/// them as small push buttons with the primary one last, as a Mac dialog
/// does.
class ProviderActionStack extends StatelessWidget {
  const ProviderActionStack({super.key, required this.buttons});

  /// Built for the layout in use: the primary button first.
  final List<Widget> Function(bool fullWidth) buttons;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final inline = mac && !providerLargeText(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        metrics.sectionGap,
        metrics.rowPadding,
        0,
      ),
      child: inline
          ? Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: buttons(false).reversed.toList(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: buttons(true),
            ),
    );
  }
}

/// A problem with a field, under it: an icon and the words, in the error
/// colour, announced when it appears. Never colour alone.
class ProviderFieldProblem extends StatelessWidget {
  const ProviderFieldProblem(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        10,
        metrics.rowPadding,
        0,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        label: text,
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AppIcon(AppIcons.error, size: 16, color: color),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: metrics.footerSize, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A line of what is going on: a small spinner (a still hourglass with
/// reduced motion) or a warning icon, then the words. A polite live region,
/// so "Checking key…" is announced once.
class ProviderStatusLine extends StatelessWidget {
  const ProviderStatusLine(this.text, {super.key, this.warning = false});

  final String text;

  /// Shows a warning icon in place of the spinner.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final Widget icon;
    if (warning) {
      icon = AppIcon(AppIcons.warning, size: 18, color: colors.warning);
    } else if (MediaQuery.disableAnimationsOf(context)) {
      icon = AppIcon(AppIcons.waiting, size: 18, color: colors.subtleText);
    } else {
      icon = const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        12,
        metrics.rowPadding,
        0,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        label: text,
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            SizedBox(width: 18, height: 20, child: Center(child: icon)),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: metrics.subtitleSize,
                  color: warning
                      ? Theme.of(context).colorScheme.onSurface
                      : colors.subtleText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 22 pt heading of a form or step, with the muted [body] under it.
class ProviderHeading extends StatelessWidget {
  const ProviderHeading({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final body = this.body;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        metrics.sectionGap,
        metrics.rowPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (body != null)
            Text(
              body,
              style: TextStyle(
                fontSize: metrics.titleSize,
                color: context.hermesColors.subtleText,
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded tile with an icon in it, [size] points square.
class ProviderIconTile extends StatelessWidget {
  const ProviderIconTile({super.key, required this.icon, this.size = 40});

  final AppIconSet icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        alignment: Alignment.center,
        child: AppIcon(icon, size: size * 0.55, color: scheme.primary),
      ),
    );
  }
}
