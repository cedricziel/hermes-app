import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../../theme/hermes_theme.dart';
import 'tool_call_bodies.dart';
import 'tool_value_view.dart';
import '../../../l10n/l10n.dart';
import '../tool_value_budget.dart';
import '../tool_value_language.dart';

/// Readable, selectable argument values without JSON quoting around commands.
/// Strings keep their exact whitespace; formatting never rewrites shell code.
class ToolArgumentsView extends StatelessWidget {
  const ToolArgumentsView({super.key, required this.arguments, this.title});

  final Map<String, Object?> arguments;

  /// The frame's label; null reads the localized "Input".
  final String? title;

  @override
  Widget build(BuildContext context) => ToolBodyFrame(
    label: title ?? context.l10n.chatWidgetsToolArgumentsTitle,
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
  late String _text;
  late ToolValueShape _shape;
  ToolValueBudget? _budget;
  var _colour = true;

  @override
  void initState() {
    super.initState();
    _make();
  }

  /// Re-reads the value, but parses again only when its text changed.
  @override
  void didUpdateWidget(_StructuredValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_encode() != _text) _make();
  }

  @override
  void dispose() {
    _budget?.release(this);
    super.dispose();
  }

  String _encode() =>
      wellFormedText(const JsonEncoder.withIndent('  ').convert(widget.value));

  void _make() {
    _text = _encode();
    final judged = judgeToolValueColour(
      toolValueShape(_text, language: 'json'),
      budget: _budget ??= ToolValueBudgetScope.maybeOf(context),
      owner: this,
      chars: _text.length,
    );
    _shape = judged.shape;
    _colour = judged.colour;
  }

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
    final notice = _shape.notice == ToolValueNotice.colourBudgetSpent
        ? ToolValueNoticeLine(
            text: context.l10n.chatWidgetsToolValueNoticeColourBudget,
          )
        : null;
    if (_shape.offersTree) {
      return ToolJsonView(
        // The tree it shows is for this text: another value, another view.
        key: ValueKey(_text),
        text: _text,
        nodes: _shape.tree,
        header: label,
        bodyMaxHeight: ToolValuePanel.maxHeight,
        section: ToolValueSection.input,
        colour: _colour,
        notice: notice,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        ?notice,
        const SizedBox(height: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: ToolValuePanel.maxHeight,
          ),
          child: SingleChildScrollView(
            child: ToolValueView(
              text: _text,
              language: _colour ? _shape.language : null,
            ),
          ),
        ),
      ],
    );
  }
}
