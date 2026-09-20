import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';

/// A compact summary of a tool the agent ran — assistant-ui surfaces tool
/// calls as their own inline card rather than mixing them into the message
/// prose, so the reasoning stays scannable. Tapping it opens what the tool was
/// given and what it returned.
class ToolCallCard extends StatelessWidget {
  const ToolCallCard({super.key, required this.call});

  final ToolCall call;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final input = _pretty(call.summary);
    final result = call.result.trim();
    final expandable = input.isNotEmpty || result.isNotEmpty;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: scheme.outline),
    );
    final fill = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return ExpansionTile(
      enabled: expandable,
      dense: true,
      shape: shape,
      collapsedShape: shape,
      backgroundColor: fill,
      collapsedBackgroundColor: fill,
      clipBehavior: Clip.antiAlias,
      tilePadding: const EdgeInsets.symmetric(horizontal: 10),
      childrenPadding: EdgeInsets.zero,
      minTileHeight: 36,
      iconColor: context.hermesColors.subtleText,
      collapsedIconColor: context.hermesColors.subtleText,
      trailing: expandable ? null : const SizedBox.shrink(),
      title: Row(
        children: [
          _StatusIcon(status: call.status),
          const SizedBox(width: 8),
          Text(
            call.name,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              call.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: context.hermesColors.subtleText,
              ),
            ),
          ),
        ],
      ),
      children: [
        if (input.isNotEmpty) _Section(label: 'Input', text: input),
        if (result.isNotEmpty) _Section(label: 'Result', text: result),
      ],
    );
  }
}

/// Arguments arrive as a compact JSON string; indent it so it reads.
String _pretty(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
  } on FormatException {
    return trimmed;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.text});

  final String label;
  final String text;

  static const double _maxHeight = 220;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.hermesColors.subtleText,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            child: SingleChildScrollView(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final ToolCallStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ToolCallStatus.running:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ToolCallStatus.completed:
        return const Icon(
          Icons.check_circle,
          size: 14,
          color: Color(0xFF16A34A),
        );
      case ToolCallStatus.error:
        return Icon(
          Icons.error,
          size: 14,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}
