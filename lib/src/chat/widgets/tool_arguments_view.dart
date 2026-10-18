import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import 'tool_call_bodies.dart';

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
                Text(
                  _label(entry.key),
                  style: TextStyle(
                    color: context.hermesColors.subtleText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  _value(entry.value),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  static String _value(Object? value) => value is String
      ? value.isEmpty
            ? '""'
            : value
      : const JsonEncoder.withIndent('  ').convert(value);

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
