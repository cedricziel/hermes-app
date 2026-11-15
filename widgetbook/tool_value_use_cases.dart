import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/chat_models.dart' show ToolCallStatus;
import 'package:hermes_app/src/chat/tool_value_language.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart'
    show ToolCallStatusIcon;
import 'package:hermes_app/src/chat/widgets/tool_value_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _jsonInput =
    '{"path": "lib/main.dart", "offset": 0, "limit": 200, '
    '"options": {"follow_symlinks": false, "encoding": "utf-8"}, '
    '"tags": ["entrypoint", "dart"], "note": null}';

const _jsonResult = '''
{
  "status": "ok",
  "count": 3,
  "items": [
    {"id": 1, "title": "Open pull requests", "draft": false, "score": 0.92},
    {"id": 2, "title": "Fix flaky test", "draft": true, "score": 0.4},
    {"id": 3, "title": "Release 1.4", "draft": false, "score": null}
  ]
}''';

const _dartOutput = '''
import 'package:flutter/material.dart';

/// Starts the app.
void main() {
  runApp(const MyApp(title: 'Hermes', retries: 3));
}
''';

const _pythonContent = '''
import json

def summarize(path: str) -> dict:
    """Count the lines of a file."""
    with open(path) as handle:
        lines = handle.readlines()
    return {"path": path, "lines": len(lines)}

print(json.dumps(summarize("notes.txt")))
''';

const _plain = 'Build finished in 12.4 s\n3 warnings, 0 errors\nDone.';

// Control and bidirectional characters: a right-to-left override in a name,
// an escape sequence and a zero-width space.
final _control = [
  'rm -rf /tmp/',
  String.fromCharCode(0x202E),
  'gpj.txt\nprogress',
  String.fromCharCode(0x1B),
  '[31m red\nzero',
  String.fromCharCode(0x200B),
  'width',
].join();

String _large() => [
  for (var i = 0; i < 160; i++)
    'def handler_$i(request):\n    return {"id": $i, "ok": True}\n',
].join('\n');

String _huge() => List.generate(
  9000,
  (i) => 'line $i: the quick brown fox jumps over the lazy dog',
).join('\n');

/// A card of the same shape as the tool call card, with plain-model sections,
/// since the sections are not wired into it yet.
Widget _card(
  BuildContext context, {
  required String name,
  required String summary,
  required ToolCallStatus status,
  required List<Widget> sections,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: scheme.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              ToolCallStatusIcon(status: status),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
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
        ),
        ...sections,
      ],
    ),
  );
}

WidgetbookUseCase _case(
  String name, {
  required String callName,
  required String summary,
  ToolCallStatus status = ToolCallStatus.completed,
  required List<Widget> Function() sections,
}) => WidgetbookUseCase(
  name: name,
  builder: (context) => frame(
    _card(
      context,
      name: callName,
      summary: summary,
      status: status,
      sections: sections(),
    ),
  ),
);

ToolValuePanel _panel(
  String label,
  String text, {
  String? path,
  bool isCommand = false,
  bool settled = true,
  bool tree = false,
}) => ToolValuePanel(
  label: label,
  text: text,
  language: toolValueLanguage(text, path: path, isCommand: isCommand),
  settled: settled,
  initiallyTree: tree,
);

WidgetbookNode toolValueNode() => WidgetbookComponent(
  name: 'ToolValuePanel',
  useCases: [
    _case(
      'JSON input',
      callName: 'read_file',
      summary: 'lib/main.dart',
      sections: () => [_panel('Input', _jsonInput)],
    ),
    _case(
      'JSON result',
      callName: 'mcp__github__list_pull_requests',
      summary: 'Open pull requests',
      sections: () => [
        _panel('Input', _jsonInput),
        _panel('Result', _jsonResult),
      ],
    ),
    _case(
      'JSON result, tree view',
      callName: 'mcp__github__list_pull_requests',
      summary: 'Open pull requests',
      sections: () => [_panel('Result', _jsonResult, tree: true)],
    ),
    _case(
      'Code output (Dart)',
      callName: 'read_file',
      summary: 'lib/main.dart',
      sections: () => [_panel('Result', _dartOutput, path: 'lib/main.dart')],
    ),
    _case(
      'Code argument (write_file)',
      callName: 'write_file',
      summary: 'tools/summarize.py',
      sections: () => [
        _panel('Content', _pythonContent, path: 'tools/summarize.py'),
      ],
    ),
    _case(
      'Terminal command and output',
      callName: 'terminal',
      summary: 'flutter build',
      sections: () => [
        _panel(
          'Command',
          'flutter build apk --release\necho "done" # ok',
          isCommand: true,
        ),
        _panel('Output', _plain),
      ],
    ),
    _case(
      'Plain text',
      callName: 'web_search',
      summary: 'build times',
      sections: () => [_panel('Result', _plain)],
    ),
    _case(
      'Large output (coloured by a worker)',
      callName: 'read_file',
      summary: 'handlers.py',
      sections: () => [_panel('Result', _large(), path: 'handlers.py')],
    ),
    _case(
      'Very large output (plain)',
      callName: 'terminal',
      summary: 'cat build.log',
      sections: () => [_panel('Output', _huge())],
    ),
    _case(
      'Control and bidi characters',
      callName: 'terminal',
      summary: 'rm',
      sections: () => [_panel('Output', _control)],
    ),
    _case(
      'Running (plain)',
      callName: 'read_file',
      summary: 'lib/main.dart',
      status: ToolCallStatus.running,
      sections: () => [
        _panel(
          'Input',
          '{"path": "lib/main.dart", "offset": 0, "li',
          settled: false,
        ),
      ],
    ),
    _case(
      'Failed',
      callName: 'read_file',
      summary: 'missing.dart',
      status: ToolCallStatus.error,
      sections: () => [
        _panel('Input', '{"path": "missing.dart"}'),
        _panel('Error', 'FileNotFoundError: missing.dart does not exist'),
      ],
    ),
    _case(
      'Invalid JSON',
      callName: 'mcp__custom__query',
      summary: 'broken payload',
      sections: () => [_panel('Result', '{"status": "ok", "items": [1, 2,')],
    ),
  ],
);
