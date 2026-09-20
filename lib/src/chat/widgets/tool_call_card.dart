import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

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
    final input = call.summary.trim();
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

bool _isJsonContainer(String text) {
  if (!text.startsWith('{') && !text.startsWith('[')) return false;
  try {
    final decoded = jsonDecode(text);
    return decoded is Map || decoded is List;
  } on FormatException {
    return false;
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
    final subtle = context.hermesColors.subtleText;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4);
    final Widget body = _isJsonContainer(text)
        ? JsonView.string(
            text,
            theme: JsonViewTheme(
              backgroundColor: Colors.transparent,
              defaultTextStyle: mono.copyWith(color: scheme.onSurface),
              keyStyle: TextStyle(color: subtle),
              stringStyle: TextStyle(color: scheme.onSurface),
              intStyle: TextStyle(color: scheme.secondary),
              doubleStyle: TextStyle(color: scheme.secondary),
              boolStyle: TextStyle(
                color: scheme.secondary,
                fontWeight: FontWeight.w600,
              ),
              openIcon: Icon(Icons.arrow_drop_down, size: 18, color: subtle),
              closeIcon: Icon(Icons.arrow_right, size: 18, color: subtle),
            ),
          )
        : SingleChildScrollView(
            child: Text(text, style: mono.copyWith(color: scheme.onSurface)),
          );
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
              color: subtle,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            child: body,
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
