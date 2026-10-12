import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';

class McpJsonField extends StatelessWidget {
  const McpJsonField({
    super.key,
    required this.controller,
    this.readOnly = false,
  });
  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(metrics.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: EdgeInsets.all(metrics.rowPadding),
      child: TextField(
        key: const ValueKey('mcp-json-text'),
        controller: controller,
        readOnly: readOnly,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartQuotesType: SmartQuotesType.disabled,
        smartDashesType: SmartDashesType.disabled,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'MCP servers JSON',
          floatingLabelBehavior: FloatingLabelBehavior.never,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
