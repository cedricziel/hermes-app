import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// How a banner reads: worked, needs attention, failed.
enum McpTone { success, warning, error }

/// A tinted box with an icon, a title and optional detail and action.
class McpBanner extends StatelessWidget {
  const McpBanner({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.detail = '',
    this.action,
  });

  final McpTone tone;
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      McpTone.success => context.hermesColors.success,
      McpTone.warning => context.hermesColors.warning,
      McpTone.error => scheme.error,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (detail.isNotEmpty) Text(detail),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
