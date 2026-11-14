import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/named_icon_button.dart';

/// A button in the bar of a page pushed inside the Activity panel, such as
/// Refresh.
class ActivityPageAction {
  const ActivityPageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.key,
  });

  /// The accessible name and tooltip.
  final String label;
  final AppIconSet icon;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final Key? key;
}

/// A page pushed inside the Activity panel (the phone sheet or the inspector):
/// a bar with Back, the title over its muted subtitle and the [actions], then
/// the [body], and an optional sticky [bottom] bar.
///
/// Back, Escape and ⌘[ call [onBack]. [shortcuts] adds the page's own keys,
/// such as ⌥↑ and ⌥↓ to step through files. The title and subtitle wrap
/// instead of being cut, so the largest text size shows them whole. Takes
/// plain values and callbacks only.
class ActivityPageScaffold extends StatelessWidget {
  const ActivityPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    this.actions = const [],
    required this.body,
    this.bottom,
    this.framedBottom = true,
    this.shortcuts = const {},
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<ActivityPageAction> actions;
  final Widget body;
  final Widget? bottom;

  /// Draws [bottom] in a bar with a top border and padding; false for a
  /// widget that draws its own bar, such as `RestoreAllBar`.
  final bool framedBottom;
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final bottom = this.bottom;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NamedIconButton(
            key: const Key('activity-page-back'),
            label: MaterialLocalizations.of(context).backButtonTooltip,
            icon: AppIcons.chevronLeft,
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              // As in a navigation bar, the title stops growing at twice its
              // size, so the page keeps room for its content.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.hermesColors.subtleText,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          for (final action in actions)
            NamedIconButton(
              key: action.key,
              label: action.label,
              icon: action.icon,
              onPressed: action.onPressed,
            ),
        ],
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onBack,
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            onBack,
        ...shortcuts,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: theme.colorScheme.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // At the largest text sizes the bar and the bottom bar scroll
              // within a share of a short panel, so the content keeps room.
              Widget capped(Widget child, double share) =>
                  constraints.maxHeight.isFinite
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * share,
                      ),
                      child: SingleChildScrollView(child: child),
                    )
                  : child;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  capped(header, 0.3),
                  Expanded(child: body),
                  if (bottom != null && !framedBottom) capped(bottom, 0.4),
                  if (bottom != null && framedBottom)
                    capped(
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: bottom,
                          ),
                        ),
                      ),
                      0.4,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
