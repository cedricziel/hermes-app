import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';

/// Why a reply failed, under whatever text it kept.
class ReplyErrorNote extends StatelessWidget {
  const ReplyErrorNote(this.error, {super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    // The icon and its offset follow the text, so they stay beside the first
    // line at any text size.
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: scaler.scale(2)),
            child: AppIcon(
              AppIcons.error,
              size: scaler.scale(16),
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              error,
              style: TextStyle(color: color, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
