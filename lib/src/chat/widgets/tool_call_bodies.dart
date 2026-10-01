import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import '../tool_result.dart';

/// What an opened [ToolCall] card shows for the tools that have a view of
/// their own — assistant-ui's per-tool renderers. Null for any other tool,
/// and for a call whose arguments or result are not the shape its view
/// expects, which then falls back to the generic input and result.
///
/// A call that changed a file shows its diff, whatever the tool.
Widget? toolCallBody(ToolCall call) {
  // Live calls carry Hermes' rendered diff; a patch read from history has
  // only the plain one in its result.
  final diff = call.diff.trim().isNotEmpty
      ? call.diff
      : switch (call.resultData) {
          {'diff': final String diff} when diff.trim().isNotEmpty => diff,
          _ => '',
        };
  if (diff.isNotEmpty) return ToolDiffBody(diff: diff);
  return switch (call.name) {
    'terminal' => TerminalToolBody.of(call),
    'web_search' => WebSearchToolBody.of(call),
    'todo_list' || 'todo' => TodoToolBody.of(call),
    _ => null,
  };
}

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4);

/// The body's frame: a rule above, the card's inner padding, and a height
/// cap past which it scrolls.
class ToolBodyFrame extends StatelessWidget {
  const ToolBodyFrame({super.key, this.label, required this.child});

  final String? label;
  final Widget child;

  static const double maxHeight = 220;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = this.label;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.hermesColors.subtleText,
              ),
            ),
            const SizedBox(height: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(child: child),
          ),
        ],
      ),
    );
  }
}

/// A shell command: the command line, what it printed, why Hermes refused or
/// failed it, and its exit code when that was not 0.
class TerminalToolBody extends StatelessWidget {
  const TerminalToolBody({
    super.key,
    required this.command,
    required this.output,
    this.error = '',
    this.exitCode,
  });

  final String command;
  final String output;
  final String error;
  final int? exitCode;

  static TerminalToolBody? of(ToolCall call) {
    final command = call.args?['command'];
    if (command is! String || command.isEmpty) return null;
    final data = call.resultData;
    return TerminalToolBody(
      command: command,
      output: switch (data) {
        {'output': final String output} => output,
        _ => call.result,
      },
      error: toolResultError(data),
      exitCode: switch (data) {
        {'exit_code': final int code} => code,
        _ => null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final failed = exitCode != null && exitCode != 0;
    return ToolBodyFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: r'$ ',
                  style: TextStyle(color: subtle),
                ),
                TextSpan(
                  text: command,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: _mono.copyWith(color: scheme.onSurface),
          ),
          if (output.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              output.trimRight(),
              style: _mono.copyWith(color: scheme.onSurface),
            ),
          ],
          if (error.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              error,
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ],
          if (failed) ...[
            const SizedBox(height: 6),
            Text(
              'Exit code $exitCode',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One hit of a web search.
typedef WebSearchHit = ({String title, String url, String description});

/// A web search: the hits it found, title, address and snippet.
class WebSearchToolBody extends StatelessWidget {
  const WebSearchToolBody({super.key, required this.hits});

  final List<WebSearchHit> hits;

  static WebSearchToolBody? of(ToolCall call) {
    if (call.resultData case {'data': {'web': final List web}}) {
      final hits = [
        for (final hit in web)
          if (hit case {'url': final String url})
            (
              title: hit['title'] is String ? hit['title'] as String : url,
              url: url,
              description: hit['description'] is String
                  ? hit['description'] as String
                  : '',
            ),
      ];
      return WebSearchToolBody(hits: hits);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    return ToolBodyFrame(
      label: hits.isEmpty
          ? 'No results'
          : '${hits.length} result${hits.length == 1 ? '' : 's'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final hit in hits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  SelectableText(
                    hit.url,
                    maxLines: 1,
                    style: TextStyle(fontSize: 11.5, color: scheme.primary),
                  ),
                  if (hit.description.isNotEmpty)
                    Text(
                      hit.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subtle),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One item of the agent's task list.
typedef TodoItem = ({String content, String status});

/// The agent's task list as the todo tool left it.
class TodoToolBody extends StatelessWidget {
  const TodoToolBody({super.key, required this.items});

  final List<TodoItem> items;

  static TodoToolBody? of(ToolCall call) {
    final todos = switch (call.resultData) {
      {'todos': final List todos} => todos,
      _ => switch (call.args) {
        {'todos': final List todos} => todos,
        _ => null,
      },
    };
    if (todos == null) return null;
    return TodoToolBody(
      items: [
        for (final item in todos)
          if (item case {'content': final String content})
            (
              content: content,
              status: item['status'] is String
                  ? item['status'] as String
                  : 'pending',
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    return ToolBodyFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: switch (item.status) {
                      'completed' => Icon(
                        Icons.check_box,
                        size: 15,
                        color: context.hermesColors.success,
                      ),
                      'in_progress' => Icon(
                        Icons.indeterminate_check_box,
                        size: 15,
                        color: scheme.primary,
                      ),
                      'cancelled' => Icon(
                        Icons.disabled_by_default_outlined,
                        size: 15,
                        color: subtle,
                      ),
                      _ => Icon(
                        Icons.check_box_outline_blank,
                        size: 15,
                        color: subtle,
                      ),
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.content,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: item.status == 'cancelled'
                            ? subtle
                            : scheme.onSurface,
                        decoration: item.status == 'cancelled'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
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

final _ansi = RegExp(r'\x1B\[[0-9;]*m');

/// A unified diff, added lines green and removed ones red. Hermes colours
/// it for a terminal; those codes are dropped.
class ToolDiffBody extends StatelessWidget {
  const ToolDiffBody({super.key, required this.diff});

  final String diff;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final success = context.hermesColors.success;
    final lines = diff
        .replaceAll(_ansi, '')
        .trimRight()
        .split('\n')
        // Hermes heads its terminal rendering with a "┊ review diff" line.
        .where((line) => !line.trimLeft().startsWith('┊'))
        .toList();
    return ToolBodyFrame(
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (final (i, line) in lines.indexed)
              TextSpan(
                text: i == lines.length - 1 ? line : '$line\n',
                style: switch (line) {
                  _ when line.startsWith('+++') || line.startsWith('---') =>
                    TextStyle(color: subtle, fontWeight: FontWeight.w600),
                  _ when line.startsWith('@@') => TextStyle(color: subtle),
                  _ when line.startsWith('+') => TextStyle(
                    color: success,
                    backgroundColor: success.withValues(alpha: 0.10),
                  ),
                  _ when line.startsWith('-') => TextStyle(
                    color: scheme.error,
                    backgroundColor: scheme.error.withValues(alpha: 0.10),
                  ),
                  _ when line.contains(' → ') && i == 0 => TextStyle(
                    color: subtle,
                    fontWeight: FontWeight.w600,
                  ),
                  _ => null,
                },
              ),
          ],
        ),
        style: _mono.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
