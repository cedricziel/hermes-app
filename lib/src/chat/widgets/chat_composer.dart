import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// The pinned bottom input — a single bordered, rounded surface holding the
/// growable text field and the send action, rather than a Material
/// [TextField] with its own outline. This is the part of assistant-ui's
/// look most people recognize on sight.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.canSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool canSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(kHermesRadius + 4),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 14.5, height: 1.4),
              decoration: const InputDecoration(
                hintText: 'Message Hermes…',
                isCollapsed: true,
              ),
              onSubmitted: (_) {
                if (canSend) onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(enabled: canSend, onPressed: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? scheme.primary : scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.arrow_upward,
            size: 18,
            color: enabled ? scheme.onPrimary : context.hermesColors.subtleText,
          ),
        ),
      ),
    );
  }
}
