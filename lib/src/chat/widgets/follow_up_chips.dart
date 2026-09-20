import 'package:flutter/material.dart';

/// What the chips under the latest reply send. Hermes offers no suggestions of
/// its own, so these are the same for every reply.
const kFollowUpPrompts = [
  'Explain in more detail',
  'Give an example',
  'Summarize this',
];

/// One-tap follow-ups under the latest reply — assistant-ui's suggestions.
class FollowUpChips extends StatelessWidget {
  const FollowUpChips({super.key, required this.onPick});

  final void Function(String prompt) onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final prompt in kFollowUpPrompts)
            ActionChip(
              label: Text(prompt),
              labelStyle: const TextStyle(fontSize: 13),
              visualDensity: VisualDensity.compact,
              onPressed: () => onPick(prompt),
            ),
        ],
      ),
    );
  }
}
