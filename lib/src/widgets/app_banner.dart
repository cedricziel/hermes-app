import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

/// How a banner reads: worked, needs attention, failed, or just a note.
enum AppBannerTone { success, warning, error, neutral }

/// A tinted box with an icon, a title and optional detail and action.
///
/// The status is told by the icon and by the words of the title, never by
/// colour alone. The banner is a polite live region, so a screen reader
/// announces one that appears or changes without taking focus. It takes plain
/// values only: no controller and no lookups beyond the theme.
///
/// The action sits beside the text, and below it, at the text's leading edge,
/// when the text size is above 150% or the language is German (long words
/// would squeeze the text into a narrow column). A button action's target is
/// at least 44 pt on iOS, 48 dp on Material and 28 pt on a Mac, whatever
/// style the caller gives it, also when the button sits in a wrapper widget.
/// An action that is no button, such as a small progress indicator, is passed
/// with `actionIsButton: false` and keeps its own size.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.tone,
    this.icon,
    required this.title,
    this.detail = '',
    this.action,
    this.actionIsButton = true,
  });

  final AppBannerTone tone;

  /// The icon beside the title; each tone has a default.
  final AppIconSet? icon;
  final String title;
  final String detail;
  final Widget? action;

  /// Whether [action] is a button (or wraps one): it then gets the platform's
  /// minimum target. Pass false for anything else, such as a small progress
  /// indicator, which keeps its own size.
  final bool actionIsButton;

  static AppIconSet defaultIcon(AppBannerTone tone) => switch (tone) {
    AppBannerTone.success => AppIcons.checkCircle,
    AppBannerTone.warning => AppIcons.warning,
    AppBannerTone.error => AppIcons.error,
    AppBannerTone.neutral => AppIcons.info,
  };

  static const double _iconSize = 18;
  static const double _iconGap = 10;

  /// Whether [action] stacks under the text in this context: above 150% text
  /// size, or in German. A caller that caps its button's width while the
  /// action sits beside the text lifts the cap when this is true.
  static bool stacksAction(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 21 ||
      Localizations.maybeLocaleOf(context)?.languageCode == 'de';

  /// Gives a button [action] the platform's minimum target (a constraint
  /// around it, so a theme's compact density or the caller's own minimum
  /// cannot cut it) and, when [flush], no inner side padding, so its label
  /// lines up with the text above it while the target still extends past the
  /// label vertically. A button that sets its own side padding through
  /// `style:` is moved toward the leading edge by that padding instead (the
  /// theme cannot beat a button's own style; a button inside a Semantics,
  /// ExcludeSemantics or MergeSemantics wrapper is seen, one inside any other
  /// wrapper widget is not and is not moved). The move is done in layout, by the
  /// caller, through [_stackedShift], so the whole button stays tappable.
  /// With [isButton] false the widget is
  /// placed as it is.
  static double _stackedShift(BuildContext context, Widget action) {
    // Semantics wrappers around the button do not hide its padding.
    var button = action;
    while (true) {
      button = switch (button) {
        Semantics(:final child?) => child,
        ExcludeSemantics(:final child?) => child,
        MergeSemantics(:final child?) => child,
        _ => button,
      };
      if (button is! Semantics &&
          button is! ExcludeSemantics &&
          button is! MergeSemantics) {
        break;
      }
    }
    final own = button is ButtonStyleButton
        ? button.style?.padding?.resolve(const <WidgetState>{})
        : null;
    if (own == null) return 0;
    final direction = Directionality.of(context);
    final resolved = own.resolve(direction);
    return (direction == TextDirection.ltr ? resolved.left : resolved.right)
        .clamp(0.0, _iconSize + _iconGap);
  }

  /// The smallest height a button action is given on this platform: 48 on
  /// Material, 44 on iOS, 28 on a Mac. A caller that swaps the button for
  /// something else keeps the banner's height by using at least this.
  static double minActionTarget(BuildContext context) =>
      switch (platformChromeOf(context)) {
        PlatformChrome.material => 48.0,
        PlatformChrome.ios => kAppleMinTapTarget,
        PlatformChrome.macos => 28.0,
      };

  static Widget _target(
    BuildContext context,
    Widget action,
    bool flush,
    bool isButton,
  ) {
    final minimum = minActionTarget(context);
    final base = Theme.of(context).textButtonTheme.style;
    final style = ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: flush
          ? const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8))
          : null,
      alignment: flush ? AlignmentDirectional.centerStart : null,
    );
    Widget child = action;
    if (isButton) {
      child = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minimum, minHeight: minimum),
        child: action,
      );
    }
    return TextButtonTheme(
      data: TextButtonThemeData(style: base?.merge(style) ?? style),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      AppBannerTone.success => context.hermesColors.success,
      AppBannerTone.warning => context.hermesColors.warning,
      AppBannerTone.error => scheme.error,
      AppBannerTone.neutral => context.hermesColors.subtleText,
    };
    final stacked = action != null && stacksAction(context);
    final shift = stacked && actionIsButton
        ? _stackedShift(context, action!)
        : 0.0;
    final text = ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (detail.isNotEmpty) Text(detail),
        ],
      ),
    );
    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: AppIcon(
            icon ?? defaultIcon(tone),
            size: _iconSize,
            color: color,
          ),
        ),
        const SizedBox(width: _iconGap),
        Expanded(child: text),
        if (!stacked && action != null)
          _target(context, action!, false, actionIsButton),
      ],
    );
    // The container's own label is what a screen reader announces when the
    // banner appears; the action keeps its own node so it stays focusable.
    return Semantics(
      container: true,
      liveRegion: true,
      label: detail.isEmpty ? title : '$title. $detail',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head,
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: _iconSize + _iconGap - shift,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _target(context, action!, true, actionIsButton),
                    ),
                  ),
                ],
              )
            : head,
      ),
    );
  }
}
