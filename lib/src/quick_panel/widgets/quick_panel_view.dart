import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';

/// The quick panel's content: a slim header with the chat's title and Open in
/// Hermes, over [child]. Before the first send [child] is the composer alone
/// and the panel is as tall as it ([compact]); after it, the chat with its
/// composer, filling the panel.
class QuickPanelView extends StatelessWidget {
  const QuickPanelView({
    super.key,
    this.title,
    this.onOpenInHermes,
    this.compact = false,
    required this.child,
  });

  final bool compact;

  /// The chat's title; null before the first send.
  final String? title;

  /// Moves the chat to a conversation window (⌘O); null while there is no
  /// saved chat to move.
  final VoidCallback? onOpenInHermes;

  final Widget child;

  /// The header's height, which the panel's compact size includes.
  static const headerHeight = 36.0;

  /// The panel's width, and its height once the chat has messages. The
  /// native side caps the height at 60% of the screen.
  static const width = 680.0;
  static const expandedHeight = 540.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: headerHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? 'Ask Hermes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: muted),
                    ),
                  ),
                  Tooltip(
                    message: 'Continue in a window (⌘O)',
                    child: TextButton.icon(
                      onPressed: onOpenInHermes,
                      icon: const AppIcon(AppIcons.openExternal, size: 16),
                      label: const Text('Open in Hermes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (compact) child else Expanded(child: child),
        ],
      ),
    );
  }
}
