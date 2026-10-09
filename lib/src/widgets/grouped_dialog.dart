import 'package:flutter/material.dart';

import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'grouped_list.dart';

/// A small settings dialog whose content is [GroupedSection]s on the page
/// background: on Apple platforms a centered title with a Done button, on
/// Material a title at the leading edge, as the settings pages' bars have.
class GroupedDialog extends StatelessWidget {
  const GroupedDialog({super.key, required this.title, required this.children});

  final String title;

  /// The [GroupedSection]s, and any [GroupedDialogNote] between them.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final metrics = GroupedMetrics.of(context);
    final theme = Theme.of(context);
    final (maxWidth, radius) = switch (chrome) {
      PlatformChrome.ios => (400.0, 14.0),
      PlatformChrome.macos => (460.0, 10.0),
      PlatformChrome.material => (560.0, 28.0),
    };
    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      // A phone gives the rows, and a warning beside a switch, the width.
      insetPadding: chrome == PlatformChrome.macos
          ? null
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Title(title: title, chrome: chrome),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    metrics.gutter,
                    0,
                    metrics.gutter,
                    metrics.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A muted paragraph between or after the groups of a [GroupedDialog], set
/// like a [GroupedSection]'s footer.
class GroupedDialogNote extends StatelessWidget {
  const GroupedDialogNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        metrics.sectionGap / 2,
        metrics.rowPadding,
        0,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: metrics.footerSize,
          color: context.hermesColors.subtleText,
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, required this.chrome});

  final String title;
  final PlatformChrome chrome;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (chrome == PlatformChrome.material) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
        ),
      );
    }
    final ios = chrome == PlatformChrome.ios;
    final fontSize = ios ? 17.0 : 13.0;
    return SizedBox(
      height: ios ? kAppleNavBarHeight + 8 : 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 72),
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: ios ? FontWeight.w600 : FontWeight.w700,
                  color: onSurface,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: ios ? 4 : 8,
            child: TextButton(
              key: const Key('grouped-dialog-done'),
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600),
                minimumSize: Size(ios ? kAppleMinTapTarget : 0, ios ? 44 : 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
