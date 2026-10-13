import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import '../../theme/app_icons.dart';
import '../chat_warning_state.dart';

class AgentNoticeCard extends StatelessWidget {
  const AgentNoticeCard({
    super.key,
    required this.notice,
    this.onDismiss,
    this.onDetails,
    this.initiallyOpen = false,
  });
  final AgentNotice notice;
  final VoidCallback? onDismiss;
  final VoidCallback? onDetails;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (notice.level) {
      'warn' || 'error' => scheme.error,
      'success' => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
    return DisclosureTile(
      initiallyExpanded: initiallyOpen,
      onExpansionChanged: (open) {
        if (open) onDetails?.call();
      },
      dense: true,
      title: Row(
        children: [
          AppIcon(AppIcons.info, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notice.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss notice',
              icon: const AppIcon(AppIcons.close, size: 18),
              onPressed: onDismiss,
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(notice.text),
          ),
        ),
      ],
    );
  }
}
