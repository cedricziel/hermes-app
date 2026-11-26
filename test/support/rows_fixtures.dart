import 'package:hermes_app/src/chat/chat_models.dart';

// The result shapes of `search_files` as Hermes builds them at d923a5eb
// (`tools/file_operations.py`, `to_dict(densify=True)`), read from its source
// and not recorded from a running server; the contract PR that records the
// real bodies replaces these.

const pathGroupedFormat = 'path-grouped: a path line, then "  N: content" rows';

/// The path-grouped block Hermes sends for five or more matches.
String pathGrouped(Map<String, List<(int, String)>> byPath) => [
  for (final MapEntry(key: path, value: hits) in byPath.entries) ...[
    path,
    for (final (line, content) in hits) '  $line: $content',
  ],
].join('\n');

/// [count] matches spread over three files, as a path-grouped block.
String manyMatches(int count) => pathGrouped({
  for (var file = 0; file < 3; file++)
    'lib/src/file_$file.dart': [
      for (var hit = file; hit < count; hit += 3)
        (hit + 1, 'final value$hit = $hit;'),
    ],
});

Map<String, Object?> densifiedAnswer(
  String text, {
  required int totalCount,
  Map<String, Object?> extra = const {},
}) => {
  'total_count': totalCount,
  'matches_format': pathGroupedFormat,
  'matches_text': text,
  ...extra,
};

List<Map<String, Object?>> matchRows(int count) => [
  for (var i = 0; i < count; i++)
    {'path': 'lib/main.dart', 'line': i + 1, 'content': 'row $i'},
];

ToolCall rowsCall(
  Object? answer, {
  String name = 'search_files',
  Map<String, Object?> args = const {'pattern': 'value'},
  String text = '',
  ToolCallStatus status = ToolCallStatus.completed,
}) => ToolCall(
  name: name,
  summary: '',
  args: args,
  result: text,
  resultData: answer,
  status: status,
);
