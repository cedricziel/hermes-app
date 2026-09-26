import 'package:flutter/material.dart';

/// Why a reply failed, under whatever text it kept.
class ReplyErrorNote extends StatelessWidget {
  const ReplyErrorNote(this.error, {super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, size: 16, color: color),
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
