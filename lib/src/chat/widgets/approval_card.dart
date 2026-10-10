import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../../theme/app_icons.dart';
import '../chat_models.dart';
import 'input_card_frame.dart';

/// The button text of each approval choice, here and in the Mac menu bar item.
const approvalChoiceLabels = {
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

/// Offered when the agent sends no choices, so the card never has no way to
/// answer. Nothing broader than a single allow is granted by default.
const _defaultChoices = ['once', 'deny'];

/// The choices the card for [request] offers: what the agent listed, or the
/// narrowest pair when it listed none.
List<String> offeredApprovalChoices(ApprovalRequest request) =>
    request.choices.isEmpty ? _defaultChoices : request.choices;

/// Asks before an approval is answered "always", which grants more than the
/// command in front of the user.
Future<bool> confirmAlwaysAllow(BuildContext context) => showConfirmDialog(
  context,
  title: 'Always allow this?',
  message: 'Hermes will run matching commands without asking again.',
  confirmLabel: 'Yes, always allow',
);

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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (choice == 'always' && !await confirmAlwaysAllow(context)) return;
      if (!mounted) return;
      await widget.onAnswer!(choice);
    } on Object catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _button(String choice) {
    final onPressed = _busy || widget.onAnswer == null
        ? null
        : () => _choose(choice);
    final label = Text(approvalChoiceLabels[choice] ?? choice);
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
      icon: AppIcons.shield,
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
              children: [
                for (final choice in offeredApprovalChoices(request))
                  _button(choice),
              ],
            ),
            InputRequestStatus.answered => InputCardNote(
              _outcomes[request.choice] ?? 'Answered',
            ),
            InputRequestStatus.expired => const InputCardNote(
              'This request timed out',
            ),
          },
          if (_error != null && request.status == InputRequestStatus.pending)
            InputCardNote(_error!, error: true),
        ],
      ),
    );
  }
}
