import 'package:flutter/material.dart';

/// A centered message for a screen with nothing to show: empty, failed to
/// load, or not available on this server. An [action] (a retry button, say)
/// sits below the text.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData? icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 40),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
