import 'package:flutter/material.dart';

/// Explains the messaging destination without depending on a connection.
class MessagingIntroduction extends StatelessWidget {
  const MessagingIntroduction({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      'Connect Hermes to Telegram, Discord, and other messaging platforms.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}
