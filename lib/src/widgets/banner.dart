import 'package:flutter/material.dart' hide Banner;
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// How a banner reads: worked, needs attention, failed, or just a note.
enum BannerTone { success, warning, error, neutral }

/// A tinted box with an icon, a title and optional detail and action.
///
/// The status is told by the icon and by the words of the title, never by
/// colour alone. The banner is a polite live region, so a screen reader
/// announces one that appears or changes without taking focus. It takes plain
/// values only: no controller and no lookups beyond the theme.
class Banner extends StatelessWidget {
  const Banner({
    super.key,
    required this.tone,
    this.icon,
    required this.title,
    this.detail = '',
    this.action,
  });

  final BannerTone tone;

  /// The icon beside the title; each tone has a default.
  final AppIconSet? icon;
  final String title;
  final String detail;
  final Widget? action;

  static AppIconSet defaultIcon(BannerTone tone) => switch (tone) {
    BannerTone.success => AppIcons.checkCircle,
    BannerTone.warning => AppIcons.warning,
    BannerTone.error => AppIcons.error,
    BannerTone.neutral => AppIcons.info,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      BannerTone.success => context.hermesColors.success,
      BannerTone.warning => context.hermesColors.warning,
      BannerTone.error => scheme.error,
      BannerTone.neutral => context.hermesColors.subtleText,
    };
    final stacked =
        action != null && MediaQuery.textScalerOf(context).scale(14) > 21;
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
          child: AppIcon(icon ?? defaultIcon(tone), size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: text),
        if (!stacked) ?action,
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
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
                ],
              )
            : head,
      ),
    );
  }
}
