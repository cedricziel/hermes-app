import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../share/shared_item.dart';
import '../../theme/hermes_theme.dart';
import '../queued_prompt.dart';
import 'queued_prompts.dart';

/// The chat composer: a card with the text field on top and, below it,
/// attach, [modelPill], and send. The stop bar, the [queued] prompts and the
/// [attachments] are listed above the card.
///
/// [attachments] count as sendable content on their own, so a blank field
/// then sends an empty text through [onSend], which the caller pairs with its
/// pending attachments. The composer never clears [controller]: the caller
/// does once it accepts the send, so a refused send keeps the text. While
/// [replying] a send is queued, so the hint says so. Enter sends and
/// Shift+Enter breaks the line.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onRemoveAttachment,
    this.onAttach,
    this.attachments = const [],
    this.replying = false,
    this.onStop,
    this.queued = const [],
    this.onRemoveQueued,
    this.onSendQueued,
    this.modelPill,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onAttach;
  final List<SharedFile> attachments;
  final ValueChanged<SharedFile> onRemoveAttachment;
  final bool replying;
  final Future<void> Function()? onStop;
  final List<QueuedPrompt> queued;
  final ValueChanged<QueuedPrompt>? onRemoveQueued;
  final VoidCallback? onSendQueued;
  final Widget? modelPill;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final _focusNode = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _canSend =>
      widget.controller.text.trim().isNotEmpty || widget.attachments.isNotEmpty;

  void _send() {
    if (_canSend) widget.onSend(widget.controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final onStop = widget.onStop;
    final onRemoveQueued = widget.onRemoveQueued;
    final modelPill = widget.modelPill;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onStop != null) _StopBar(onStop: onStop),
        if (widget.queued.isNotEmpty && onRemoveQueued != null)
          QueuedPrompts(
            prompts: widget.queued,
            onRemove: onRemoveQueued,
            onSendNow: widget.onSendQueued,
          ),
        if (widget.attachments.isNotEmpty)
          _AttachmentChips(
            attachments: widget.attachments,
            onRemove: widget.onRemoveAttachment,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(kHermesRadius + 6),
              border: Border.all(color: scheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: widget.replying
                          ? 'Queue a message…'
                          : 'Message Hermes…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.onAttach case final onAttach?)
                        IconButton(
                          tooltip: 'Add attachment',
                          icon: const Icon(Icons.add),
                          color: subtle,
                          onPressed: onAttach,
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: modelPill,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) => IconButton.filled(
                          tooltip: 'Send',
                          icon: const Icon(Icons.arrow_upward),
                          // The app's icon button theme would paint the arrow
                          // in onSurface, invisible on a dark primary.
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            disabledBackgroundColor: scheme.onSurface
                                .withValues(alpha: 0.08),
                            disabledForegroundColor: subtle,
                          ),
                          onPressed: _canSend ? _send : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
