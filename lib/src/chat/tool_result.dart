import 'dart:convert';

import '../memory/memory_tool_outcome.dart';
import 'chat_models.dart';

/// How a tool call ended, read from what it returned: Hermes sends no status
/// of its own, live or in history.
///
/// A result is cancelled when the run was killed, which every Hermes executor
/// marks by ending the output with a bracketed "[Command interrupted]" or
/// "[execution interrupted]" line (Hermes' `is_interrupted_tool_result`). It
/// failed when it carries an `error`, or a shell command exited non-zero.
///
/// The `memory` tool (given as [name]) reports a full file as an error, but
/// nothing went wrong: Hermes usually makes room and tries again, so that
/// is a warning.
ToolCallStatus toolResultStatus(Object? result, {String name = ''}) {
  if (isInterruptedToolResult(result)) return ToolCallStatus.cancelled;
  if (result is! Map) return ToolCallStatus.completed;
  if (name == 'memory' &&
      MemoryToolOutcome.parse(result: result)?.kind == MemoryOutcomeKind.full) {
    return ToolCallStatus.warning;
  }
  final error = result['error'];
  if (error != null && error != '' && error != false) {
    return ToolCallStatus.error;
  }
  final code = result['exit_code'];
  if (code is int && code != 0) return ToolCallStatus.error;
  return ToolCallStatus.completed;
}

final _interruptMarker = RegExp(
  r'^\[(?:command|execution) interrupted\b[^\n]*\]\s*$',
  caseSensitive: false,
);

/// Whether [result] has the shape of a killed run: the interrupt marker is
/// the last line of its output, and a JSON result also has a non-zero exit
/// code. The marker quoted inside a successful output is ordinary data.
bool isInterruptedToolResult(Object? result) {
  final String output;
  switch (result) {
    case String():
      output = result;
    case {'output': final String text}:
      final code = result['exit_code'];
      if (code == null || code == 0) return false;
      output = text;
    default:
      return false;
  }
  final lines = output.trimRight().split('\n');
  return _interruptMarker.hasMatch(lines.last);
}

/// The text of a result's `error` field, when it has one.
String toolResultError(Object? result) => switch (result) {
  {'error': final String error} => error.trim(),
  _ => '',
};

/// The object a call's result is, for the views that read its keys: the
/// decoded [ToolCall.resultData] when it is an object, else the JSON object
/// that [ToolCall.resultData] or [ToolCall.result] holds as text (live, a
/// result may reach a view as a string). Null for a list, a text that is not
/// JSON and a call with no result.
Map<String, Object?>? toolResultMap(ToolCall call) {
  final data = call.resultData;
  if (data is Map) return data.cast<String, Object?>();
  // A JSON text can arrive as the result data itself (live) or as the
  // result text.
  final text = data is String ? data : call.result;
  if (data != null && data is! String || text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}
