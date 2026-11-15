import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';
import '../navigation/desktop_navigation_history.dart';

/// The back button of a pushed screen: on iOS a chevron with the title of the
/// screen underneath, elsewhere the stock [BackButton], which already draws a
/// chevron on macOS.
///
/// Pass it as `AppBar.leading` together with
/// `leadingWidth: adaptiveBackLeadingWidth(context)`. It draws nothing when
/// there is no route to go back to.
class AdaptiveBackButton extends StatelessWidget {
  const AdaptiveBackButton({
    super.key,
    this.previousTitle,
    this.collapseLabel = false,
  });

  /// The title of the screen underneath, or null to show "Back".
  final String? previousTitle;

  /// On iOS, draws the chevron alone, in a 44 point target, and keeps the
  /// label as the button's accessible name; for the largest text sizes, where
  /// the label would crowd out the bar's title and trailing action.
  final bool collapseLabel;

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();
    if (platformChromeOf(context) != PlatformChrome.ios) {
      final desktop = const {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(Theme.of(context).platform);
      final history = desktop
          ? DesktopNavigationHistoryScope.maybeOf(context)
          : null;
      return BackButton(
        onPressed: history == null || history.navigator != Navigator.of(context)
            ? null
            : () => history.back(),
      );
    }
    if (collapseLabel) {
      return _ChevronOnlyBackButton(
        label: previousTitle ?? 'Back',
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return CupertinoNavigationBarBackButton(
      previousPageTitle: previousTitle,
      color: Theme.of(context).colorScheme.primary,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// The `AppBar.leadingWidth` that leaves room for the iOS label, or null for
/// the default.
double? adaptiveBackLeadingWidth(BuildContext context) =>
    platformChromeOf(context) != PlatformChrome.ios
    ? null
    : largeBarText(context)
    ? kCollapsedLeadingWidth
    : scaledLeadingWidth(context, 120);

/// The text scale from which a bar drops its leading label (the back button's
/// title, "Cancel") for an icon, so the title and the trailing action fit.
const double kLargeBarTextScale = 1.5;

/// The width of a collapsed leading item: a 44 point target and a margin.
const double kCollapsedLeadingWidth = 52;

/// Whether the text is large enough that a bar's leading label collapses.
bool largeBarText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(17) / 17 >= kLargeBarTextScale;

class _ChevronOnlyBackButton extends StatelessWidget {
  const _ChevronOnlyBackButton({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkResponse(
        onTap: () => Navigator.of(context).maybePop(),
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            CupertinoIcons.back,
            size: 30,
            color: color,
            // Mirrors the chevron in a right-to-left layout.
            textDirection: Directionality.of(context),
            applyTextScaling: false,
          ),
        ),
      ),
    ),
  );
}

/// [base] widened with the text size, so a bar label such as "Cancel" or the
/// back button's title is not cut at the largest sizes, up to half the
/// window's width.
double scaledLeadingWidth(BuildContext context, double base) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  final room = MediaQuery.sizeOf(context).width * 0.5;
  final wanted = base * (scale > 1 ? scale : 1);
  return wanted < room ? wanted : (room > base ? room : base);
}
