import 'dart:convert';

import 'package:flutter/material.dart';

import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../../theme/hermes_theme.dart';
import 'tool_call_bodies.dart';
import 'tool_value_view.dart';
import '../tool_value_language.dart';

/// Readable, selectable argument values without JSON quoting around commands.
/// Strings keep their exact whitespace; formatting never rewrites shell code.
class ToolArgumentsView extends StatelessWidget {
  const ToolArgumentsView({
    super.key,
    required this.arguments,
    this.title = 'Input',
  });

  final Map<String, Object?> arguments;
  final String title;

  @override
  Widget build(BuildContext context) => ToolBodyFrame(
    label: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in arguments.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entry.value is Map || entry.value is List)
                  _StructuredValue(
                    label: wellFormedText(_label(entry.key)),
                    value: entry.value!,
                  )
                else ...[
                  Text(
                    wellFormedText(_label(entry.key)),
                    style: TextStyle(
                      color: context.hermesColors.subtleText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(_value(entry.value), style: kToolMonoStyle),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  static String _value(Object? value) => wellFormedText(
    value is String
        ? value.isEmpty
              ? '""'
              : value
        : const JsonEncoder.withIndent('  ').convert(value),
  );

  static String _label(String key) => switch (key) {
    'cwd' || 'workdir' => 'Working directory',
    'timeout_s' => 'Timeout (seconds)',
    'timeout_ms' => 'Timeout (milliseconds)',
    _ =>
      key.isEmpty
          ? 'Value'
          : '${key[0].toUpperCase()}${key.substring(1).replaceAll('_', ' ')}',
  };
}

/// A map or list argument: coloured as JSON, with the switch to the tree when
/// it is on offer, boxed at 220 pt like a section. Text values stay as they
/// are above, verbatim and selectable. It is built when the card opens.
class _StructuredValue extends StatefulWidget {
  const _StructuredValue({required this.label, required this.value});

  final String label;
  final Object value;

  @override
  State<_StructuredValue> createState() => _StructuredValueState();
}

class _StructuredValueState extends State<_StructuredValue> {
  late final String _text = wellFormedText(
    const JsonEncoder.withIndent('  ').convert(widget.value),
  );
  late final ToolValueShape _shape = toolValueShape(_text, language: 'json');

  @override
  Widget build(BuildContext context) {
    final label = Text(
      widget.label,
      style: TextStyle(
        color: context.hermesColors.subtleText,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
    );
    if (_shape.offersTree) {
      return ToolJsonView(
        text: _text,
        nodes: _shape.tree,
        header: label,
        bodyMaxHeight: ToolValuePanel.maxHeight,
        section: ToolValueSection.input,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        const SizedBox(height: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: ToolValuePanel.maxHeight,
          ),
          child: SingleChildScrollView(
            child: ToolValueView(text: _text, language: _shape.language),
          ),
        ),
      ],
    );
  }
}
