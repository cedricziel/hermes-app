import 'chat_models.dart';

/// How a tool call ended, read from what it returned: Hermes sends no status
/// of its own, live or in history.
///
/// A result is cancelled when the run was killed, which every Hermes executor
/// marks by ending the output with a bracketed "[Command interrupted]" or
/// "[execution interrupted]" line (Hermes' `is_interrupted_tool_result`). It
/// failed when it carries an `error`, or a shell command exited non-zero.
ToolCallStatus toolResultStatus(Object? result) {
  if (isInterruptedToolResult(result)) return ToolCallStatus.cancelled;
  if (result is! Map) return ToolCallStatus.completed;
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
