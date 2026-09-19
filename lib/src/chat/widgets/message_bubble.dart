import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import 'message_content.dart';
import 'thinking_indicator.dart';
import 'tool_call_card.dart';

/// A single row in the thread — assistant-ui's signature asymmetry: the
/// user's turn is a bounded, right-aligned chip; the agent's turn is
/// unbounded plain text under a small avatar, so long answers read like
/// prose rather than a stack of speech bubbles.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return message.role == ChatRole.user
        ? _UserMessage(message: message)
        : _AssistantMessage(message: message);
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(kHermesRadius),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, size: 14, color: scheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final call in message.toolCalls)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ToolCallCard(call: call),
                  ),
                if (message.status == MessageStatus.thinking)
                  const ThinkingIndicator()
                else
                  MessageContent(
                    text: message.content,
                    baseStyle: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                if (message.status == MessageStatus.sent) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ActionIcon(
                        icon: Icons.copy_outlined,
                        tooltip: 'Copy',
                        onTap: () => Clipboard.setData(
                          ClipboardData(text: message.content),
                        ),
                      ),
                    ],
                  ),
                ] else if (message.status == MessageStatus.streaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Streaming…',
                      style: TextStyle(fontSize: 11, color: subtle),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 15, color: context.hermesColors.subtleText),
        ),
      ),
    );
  }
}
