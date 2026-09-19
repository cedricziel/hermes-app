import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'input_card_frame.dart';

const _labels = {
  'once': 'Allow once',
  'session': 'Allow for session',
  'always': 'Always allow',
  'deny': 'Deny',
};

const _outcomes = {
  'once': 'Allowed once',
  'session': 'Allowed for this session',
  'always': 'Always allowed',
  'deny': 'Denied',
};

const kAnswerFailedMessage = 'Could not send your answer. Try again.';

/// The agent wants to run something and waits for the user to allow or deny
/// it. Once answered or expired the buttons give way to the outcome.
class ApprovalCard extends StatefulWidget {
  const ApprovalCard({super.key, required this.request, this.onAnswer});

  final ApprovalRequest request;

  /// Sends the choice. Throwing means it did not go through. Without one the
  /// buttons are disabled.
  final Future<void> Function(String choice)? onAnswer;

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard> {
  var _busy = false;
  String? _error;

  Future<void> _choose(String choice) async {
    if (_busy) return;
    if (choice == 'always' && !await _confirmAlways()) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAnswer!(choice);
    } catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmAlways() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Always allow this?'),
        content: const Text(
          'Hermes will run matching commands without asking again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, always allow'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Widget _button(String choice) {
    final onPressed = _busy || widget.onAnswer == null
        ? null
        : () => _choose(choice);
    final label = Text(_labels[choice] ?? choice);
    return switch (choice) {
      'once' => FilledButton.tonal(onPressed: onPressed, child: label),
      'deny' => TextButton(onPressed: onPressed, child: label),
      _ => OutlinedButton(onPressed: onPressed, child: label),
    };
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final scheme = Theme.of(context).colorScheme;
    return InputCardFrame(
      icon: Icons.shield_outlined,
      title: 'Approval needed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(request.description),
            ),
          if (request.command.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outline),
              ),
              child: SelectableText(
                request.command,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 10),
          switch (request.status) {
            InputRequestStatus.pending => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final choice in request.choices) _button(choice)],
            ),
            InputRequestStatus.answered => InputCardNote(
              _outcomes[request.choice] ?? 'Answered',
            ),
            InputRequestStatus.expired => const InputCardNote(
              'This request timed out',
            ),
          },
          if (_error != null) InputCardNote(_error!, error: true),
        ],
      ),
    );
  }
}
