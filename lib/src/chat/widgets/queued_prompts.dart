import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../queued_prompt.dart';
import '../../widgets/named_icon_button.dart';
import '../../widgets/disclosure_tile.dart';

/// Queued and uncertain prompts above the composer. [onSendNow] sends the
/// first unsent entry; restored queues require one explicit send per entry.
/// A locked view hides payloads, and uncertain entries cannot use this control.
class QueuedPrompts extends StatelessWidget {
  const QueuedPrompts({
    super.key,
    required this.prompts,
    required this.onRemove,
    this.onSendNow,
    this.onInspect,
    this.reviewRequired = false,
    this.available = true,
    this.locked = false,
    this.storageError,
    this.busy = false,
    this.initiallyExpanded = false,
  });

  final List<QueuedPrompt> prompts;
  final ValueChanged<QueuedPrompt> onRemove;
  final VoidCallback? onSendNow;
  final VoidCallback? onInspect;
  final bool reviewRequired;
  final bool available;
  final bool locked;
  final String? storageError;
  final bool busy;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Unlock to review queued prompts.'),
      );
    }
    if (prompts.isEmpty &&
        !busy &&
        storageError == null &&
        available &&
        !reviewRequired) {
      return const SizedBox.shrink();
    }
    final attention =
        onSendNow != null ||
        reviewRequired ||
        !available ||
        storageError != null ||
        prompts.any((p) => p.uncertain);
    final label = busy
        ? 'Queueing…'
        : reviewRequired
        ? 'Review queued messages'
        : onSendNow != null
        ? 'Queue paused · ${prompts.length}'
        : attention
        ? 'Queue needs attention'
        : '${prompts.length} queued';
    final preview = !attention && !busy && prompts.isNotEmpty
        ? ' · ${_label(prompts.first)}'
        : '';
    return Material(
      type: MaterialType.transparency,
      child: DisclosureTile(
        // A newly recovered/uncertain queue must reveal its explanation even
        // if the ordinary queue was previously collapsed by the user.
        key: ValueKey(attention),
        dense: true,
        minTileHeight: 44,
        tilePadding: const EdgeInsets.only(left: 10, right: 4),
        initiallyExpanded: attention || initiallyExpanded,
        title: Text(
          '$label$preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.hermesColors.subtleText),
        ),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  ((MediaQuery.sizeOf(context).height -
                              MediaQuery.viewInsetsOf(context).bottom) *
                          0.25)
                      .clamp(48.0, 200.0),
            ),
            child: SingleChildScrollView(child: _details(context)),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final uncertain = prompts.any((prompt) => prompt.uncertain);
    final onSendNow =
        available && !busy && !(prompts.firstOrNull?.uncertain ?? false)
        ? this.onSendNow
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  busy
                      ? 'Saving queued messages…'
                      : reviewRequired
                      ? 'Recovered queue. Review before sending.'
                      : onSendNow == null
                      ? 'Queued, sent when Hermes is done'
                      : 'Queue paused',
                  style: TextStyle(color: subtle),
                ),
              ),
              if (onSendNow != null)
                TextButton.icon(
                  onPressed: onSendNow,
                  icon: const AppIcon(AppIcons.sendOutlined),
                  label: Text(reviewRequired ? 'Send next' : 'Send now'),
                ),
            ],
          ),
          if (!available) const Text('Original conversation unavailable.'),
          if (storageError != null) Text(storageError!),
          if (uncertain) ...[
            const Text('Submission outcome unknown'),
            const Text(
              'An earlier attempt may already have reached Hermes. To send it again, enter a new prompt.',
            ),
            if (onInspect != null)
              TextButton(
                onPressed: onInspect,
                child: const Text('Inspect conversation'),
              ),
          ],
          for (final prompt in prompts)
            Row(
              children: [
                AppIcon(AppIcons.schedule, size: 16, color: subtle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _label(prompt),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (prompt.attachmentCount > 0 && prompt.text.isNotEmpty) ...[
                  AppIcon(AppIcons.attach, size: 16, color: subtle),
                  Text(
                    '${prompt.attachmentCount}',
                    style: TextStyle(color: subtle),
                  ),
                ],
                NamedIconButton(
                  label: 'Remove ${_label(prompt)} from queue',
                  tooltip: 'Remove from queue',
                  visualDensity: VisualDensity.compact,
                  icon: AppIcons.close,
                  iconSize: 18,
                  onPressed: busy || prompt.submitting
                      ? null
                      : () => onRemove(prompt),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _label(QueuedPrompt prompt) =>
      (prompt.displayText ?? prompt.text).isNotEmpty
      ? prompt.displayText ?? prompt.text
      : prompt.attachmentNames.join(', ');
}
