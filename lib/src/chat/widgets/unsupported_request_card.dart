import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'input_card_frame.dart';

/// The agent waits on something this app cannot ask for yet. The card says
/// what and where to answer it; it never collects a value.
class UnsupportedRequestCard extends StatelessWidget {
  const UnsupportedRequestCard({super.key, required this.request});

  final UnsupportedRequest request;

  @override
  Widget build(BuildContext context) {
    final asked = switch (request.kind) {
      UnsupportedKind.secret => 'a secret value, such as an API key',
      UnsupportedKind.sudo => 'your sudo password',
    };
    return InputCardFrame(
      icon: Icons.lock_outline,
      title: 'Hermes needs something else',
      child: request.status == InputRequestStatus.expired
          ? const InputCardNote('This request timed out')
          : Text(
              'Hermes asked for $asked. This app cannot ask for it yet. '
              'Answer it in the Hermes terminal or dashboard.',
            ),
    );
  }
}
