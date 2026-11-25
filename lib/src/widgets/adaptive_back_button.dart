import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../navigation/desktop_navigation_history.dart';
import 'named_icon_button.dart';
import 'settings_scaffold.dart';

/// The back button of a pushed screen: on iOS a chevron with the title of the
/// screen underneath, elsewhere the stock [BackButton], which already draws a
/// chevron on macOS.
///
/// Pass it as `AppBar.leading` together with
/// `leadingWidth: adaptiveBackLeadingWidth(context)`. It draws nothing when
/// there is no route to go back to.
class AdaptiveBackButton extends StatelessWidget {
  const AdaptiveBackButton({super.key, this.previousTitle});

  /// The title of the screen underneath, or null to show "Back".
  final String? previousTitle;

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
    // From [kLargeBarTextScale] the chevron stands alone, in a 44 point
    // target, and the title stays as the button's accessible name.
    if (largeBarText(context)) {
      final title = previousTitle;
      return CollapsedBarIconButton(
        label: title == null || title.isEmpty
            ? MaterialLocalizations.of(context).backButtonTooltip
            : title,
        icon: _backChevron,
        iconSize: 30,
        onPressed: () => Navigator.of(context).maybePop(),
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

const _backChevron = AppIconSet(Icons.arrow_back_ios_new, CupertinoIcons.back);

/// The leading item of an iOS bar once its label collapses: a glyph in a 44
/// point target (the bar's icon button style) that keeps [label] as its
/// accessible name.
class CollapsedBarIconButton extends StatelessWidget {
  const CollapsedBarIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.iconSize,
    required this.onPressed,
  });

  final String label;
  final AppIconSet icon;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: NamedIconButton(
      label: label,
      icon: icon,
      color: Theme.of(context).colorScheme.primary,
      style: SettingsScaffold.appleBarButtonStyle.copyWith(
        iconSize: WidgetStatePropertyAll(iconSize),
      ),
      onPressed: onPressed,
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
