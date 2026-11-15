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
/// would squeeze the text into a narrow column). Its target is at least 44 pt
/// on iOS, 48 dp on Material and 28 pt on a Mac, whatever button the caller
/// passes.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.tone,
    this.icon,
    required this.title,
    this.detail = '',
    this.action,
  });

  final AppBannerTone tone;

  /// The icon beside the title; each tone has a default.
  final AppIconSet? icon;
  final String title;
  final String detail;
  final Widget? action;

  static AppIconSet defaultIcon(AppBannerTone tone) => switch (tone) {
    AppBannerTone.success => AppIcons.checkCircle,
    AppBannerTone.warning => AppIcons.warning,
    AppBannerTone.error => AppIcons.error,
    AppBannerTone.neutral => AppIcons.info,
  };

  static const double _iconSize = 18;
  static const double _iconGap = 10;

  /// Gives [action] the platform's minimum target. A text button also gets
  /// the standard density (a Mac theme's compact one would cut the minimum)
  /// and, when [flush], no inner side padding, so its label lines up with the
  /// text above it while the target still extends past the label.
  static Widget _target(BuildContext context, Widget action, bool flush) {
    final minimum = switch (platformChromeOf(context)) {
      PlatformChrome.material => 48.0,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
    };
    final base = Theme.of(context).textButtonTheme.style;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(minimum, minimum)),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: flush
          ? const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8))
          : null,
      alignment: flush ? AlignmentDirectional.centerStart : null,
    );
    return TextButtonTheme(
      data: TextButtonThemeData(style: base?.merge(style) ?? style),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minimum, minHeight: minimum),
        child: action,
      ),
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
    final stacked =
        action != null &&
        (MediaQuery.textScalerOf(context).scale(14) > 21 ||
            Localizations.maybeLocaleOf(context)?.languageCode == 'de');
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
        if (!stacked && action != null) _target(context, action!, false),
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
                    padding: const EdgeInsetsDirectional.only(
                      start: _iconSize + _iconGap,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _target(context, action!, true),
                    ),
                  ),
                ],
              )
            : head,
      ),
    );
  }
}
