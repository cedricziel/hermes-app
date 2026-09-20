import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'approval_card.dart' show kAnswerFailedMessage;
import 'input_card_frame.dart';

/// The agent waits on something this app cannot ask for yet. The card says
/// what and where to answer it and lets the user skip it; it never collects a
/// value.
class UnsupportedRequestCard extends StatefulWidget {
  const UnsupportedRequestCard({super.key, required this.request, this.onSkip});

  final UnsupportedRequest request;

  /// Tells Hermes to carry on without the value. Throwing means it did not go
  /// through. Without one the button is disabled.
  final Future<void> Function()? onSkip;

  @override
  State<UnsupportedRequestCard> createState() => _UnsupportedRequestCardState();
}

class _UnsupportedRequestCardState extends State<UnsupportedRequestCard> {
  var _busy = false;
  String? _error;

  Future<void> _skip() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSkip!();
    } catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final asked = switch (request.kind) {
      UnsupportedKind.secret => 'a secret value, such as an API key',
      UnsupportedKind.sudo => 'your sudo password',
    };
    return InputCardFrame(
      icon: Icons.lock_outline,
      title: 'Hermes needs something else',
      child: switch (request.status) {
        InputRequestStatus.expired => const InputCardNote(
          'This request timed out',
        ),
        InputRequestStatus.answered => const InputCardNote(
          'You skipped this request',
        ),
        InputRequestStatus.pending => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hermes asked for $asked. This app cannot ask for it yet. '
              'Answer it in the Hermes terminal or dashboard.',
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy || widget.onSkip == null ? null : _skip,
              child: const Text('Skip'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      },
    );
  }
}
