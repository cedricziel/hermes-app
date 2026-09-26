import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../../share/shared_item.dart';
import '../../theme/hermes_theme.dart';
import '../queued_prompt.dart';
import 'queued_prompts.dart';

/// Builds flutter_chat_ui's [Composer] for the Hermes chat.
///
/// [controller] is shared with the screen so it can prefill shared text.
/// [attachments] show as removable chips above the input, and count as
/// sendable content on their own: the send button stays enabled and an empty
/// message is emitted through `Chat.onMessageSend`, which the screen pairs
/// with its pending attachments. While [replying] a send is queued, so the
/// hint says so; [onStop] then offers to stop the reply from a bar above the
/// field. The [queued] prompts are listed above it (see [QueuedPrompts]).
/// The composer never clears the field itself: the screen does once it
/// accepts the send, so a refused send keeps the text.
/// [modelPill] sits below all of that, on the left.
WidgetBuilder buildChatComposer({
  required TextEditingController controller,
  required List<SharedFile> attachments,
  required ValueChanged<SharedFile> onRemoveAttachment,
  bool replying = false,
  Future<void> Function()? onStop,
  List<QueuedPrompt> queued = const [],
  ValueChanged<QueuedPrompt>? onRemoveQueued,
  VoidCallback? onSendQueued,
  Widget? modelPill,
}) {
  return (context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAttachments = attachments.isNotEmpty;
    final hasQueue = queued.isNotEmpty && onRemoveQueued != null;
    return Composer(
      textEditingController: controller,
      hintText: replying ? 'Queue a message…' : 'Message Hermes…',
      maxLines: 8,
      sendOnEnter: true,
      attachmentIcon: const Icon(Icons.attach_file),
      attachmentIconColor: context.hermesColors.subtleText,
      sendIcon: const Icon(Icons.arrow_upward),
      sendIconColor: scheme.primary,
      emptyFieldSendIconColor: context.hermesColors.subtleText,
      backgroundColor: scheme.surface,
      inputBorder: mui.OutlineInputBorder(
        borderRadius: BorderRadius.circular(kHermesRadius),
        borderSide: BorderSide(color: scheme.outline),
      ),
      inputFillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      sigmaX: 0,
      sigmaY: 0,
      allowEmptyMessage: hasAttachments,
      inputClearMode: InputClearMode.never,
      sendButtonVisibilityMode: hasAttachments
          ? SendButtonVisibilityMode.always
          : SendButtonVisibilityMode.disabled,
      topWidget:
          hasAttachments || onStop != null || hasQueue || modelPill != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onStop != null) _StopBar(onStop: onStop),
                if (hasQueue)
                  QueuedPrompts(
                    prompts: queued,
                    onRemove: onRemoveQueued,
                    onSendNow: onSendQueued,
                  ),
                if (hasAttachments)
                  _AttachmentChips(
                    attachments: attachments,
                    onRemove: onRemoveAttachment,
                  ),
                if (modelPill != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: modelPill,
                    ),
                  ),
              ],
            )
          : null,
    );
  };
}

/// Supplies what flutter_chat_ui's [Composer] needs from `material_ui`, a
/// package separate from Flutter's own material library: a `Material`
/// ancestor, `MaterialLocalizations` and a theme seeded from the app's colors. Wrap the `Chat` in this; it cannot be
/// added from the composer builder because [Composer] returns a `Positioned`
/// that must stay a direct child of the chat's `Stack`.
class FlyerMaterialScope extends StatelessWidget {
  const FlyerMaterialScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Localizations.override(
      context: context,
      delegates: const [mui.DefaultMaterialLocalizations.delegate],
      child: mui.Theme(
        data: mui.ThemeData(
          colorScheme:
              mui.ColorScheme.fromSeed(
                seedColor: scheme.primary,
                brightness: scheme.brightness,
              ).copyWith(
                primary: scheme.primary,
                surface: scheme.surface,
                onSurface: scheme.onSurface,
              ),
        ),
        child: mui.Material(type: mui.MaterialType.transparency, child: child),
      ),
    );
  }
}

/// Shown while a reply is in flight, so it can be stopped.
class _StopBar extends StatefulWidget {
  const _StopBar({required this.onStop});

  final Future<void> Function() onStop;

  @override
  State<_StopBar> createState() => _StopBarState();
}

class _StopBarState extends State<_StopBar> {
  var _busy = false;

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onStop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hermes is replying…',
              style: TextStyle(color: context.hermesColors.subtleText),
            ),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _stop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

class _AttachmentChips extends StatelessWidget {
  const _AttachmentChips({required this.attachments, required this.onRemove});

  final List<SharedFile> attachments;
  final ValueChanged<SharedFile> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final file in attachments)
              InputChip(
                avatar: Icon(
                  file.isImage
                      ? Icons.image_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 16,
                ),
                label: Text(file.name),
                deleteButtonTooltipMessage: 'Remove ${file.name}',
                onDeleted: () => onRemove(file),
              ),
          ],
        ),
      ),
    );
  }
}
