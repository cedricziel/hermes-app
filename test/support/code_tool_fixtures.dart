import 'package:hermes_app/src/chat/chat_models.dart';

// The result shapes of `read_file` and `write_file` as Hermes builds them at
// d923a5eb (`tools/file_tools.py`, `tools/file_operations.py`), read from its
// source and not recorded from a running server; the contract PR that records
// the real bodies replaces these.

/// The rows of [lines] as Hermes numbers them: `N|text`, from [first].
String numbered(List<String> lines, {int first = 1}) =>
    [for (var i = 0; i < lines.length; i++) '${first + i}|${lines[i]}']
        .join('\n');

/// An ordinary `read_file` answer: every flag false, as `ReadResult.to_dict`
/// sends them.
Map<String, Object?> readAnswer({
  required String content,
  int? totalLines,
  Map<String, Object?> extra = const {},
}) => {
  'content': content,
  'total_lines': ?totalLines,
  'file_size': content.length,
  'truncated': false,
  'is_binary': false,
  'is_image': false,
  'not_found': false,
  ...extra,
};

ToolCall readCall(
  Object? answer, {
  Map<String, Object?>? args = const {'path': 'lib/main.dart'},
  String text = '',
  ToolCallStatus status = ToolCallStatus.completed,
}) => ToolCall(
  name: 'read_file',
  summary: '',
  args: args,
  result: text,
  resultData: answer,
  status: status,
);

ToolCall writeCall(
  Object? answer, {
  Map<String, Object?>? args = const {
    'path': 'notes/todo.md',
    'content': '# Todo\n- ship it\n',
  },
  ToolCallStatus status = ToolCallStatus.completed,
  bool preparing = false,
}) => ToolCall(
  name: 'write_file',
  summary: '',
  args: args,
  resultData: answer,
  status: status,
  preparing: preparing,
);
