import 'chat_models.dart';
import 'read_file_result.dart';
import 'tool_result.dart';

/// A `write_file` call read into what its view shows: the content as sent,
/// numbered from 1, and what Hermes reported once it answered. Pure: no
/// widget, no words. Null from [of] for arguments that are not a path and a
/// content, or a result that is not an object.
class WriteFileResult {
  const WriteFileResult._({
    required this.path,
    required this.content,
    required this.rows,
    required this.answered,
    this.error = '',
    this.bytesWritten,
    this.verified = false,
    this.lintOutput,
    this.diagnostics = '',
    this.warning = '',
    this.hint = '',
  });

  final String path;

  /// The text the model asked to write, as sent.
  final String content;
  final List<CodeRow> rows;

  /// Whether Hermes has answered; false while the call runs.
  final bool answered;

  /// Hermes' refusal; the file is untouched.
  final String error;
  final int? bytesWritten;
  final bool verified;

  /// The output of a syntax check that found a problem; null otherwise.
  final String? lintOutput;
  final String diagnostics;
  final String warning;

  /// Hermes' `_warning` (where the path resolved to) and `hint` texts.
  final String hint;

  bool get refused => error.isNotEmpty;

  static WriteFileResult? of(ToolCall call) {
    final args = call.args;
    final path = args?['path'];
    final content = args?['content'];
    if (path is! String || path.isEmpty || content is! String) return null;
    final data = toolResultMap(call);
    final hasResult = call.resultData != null || call.result.isNotEmpty;
    if (hasResult && data == null) return null;
    final lines = content.isEmpty ? <String>[] : content.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    final rows = [
      for (var i = 0; i < lines.length; i++) (number: i + 1, text: lines[i]),
    ];
    String text(String key) {
      final value = data?[key];
      return value is String ? value.trim() : '';
    }

    final lint = data?['lint'];
    return WriteFileResult._(
      path: path,
      content: content,
      rows: rows,
      answered: data != null,
      error: text('error'),
      bytesWritten: switch (data?['bytes_written']) {
        final int bytes => bytes,
        _ => null,
      },
      verified: data?['verified'] == true,
      lintOutput: switch (lint) {
        {'status': 'error', 'output': final String output} => output.trim(),
        {'status': 'error'} => '',
        _ => null,
      },
      diagnostics: text('lsp_diagnostics'),
      warning: [
        text('warning'),
        text('_warning'),
      ].where((part) => part.isNotEmpty).join('\n'),
      hint: text('hint'),
    );
  }
}
