import 'package:hermes_app/src/chat/chat_models.dart';

// The result shapes of `browser_navigate` and `web_extract` as Hermes builds
// them at d923a5eb (`tools/browser_tool.py`, `tools/web_tools.py`), read from
// its source and not recorded from a running server; the contract PR that
// records the real bodies replaces these.

/// A `browser_navigate` answer that opened [url].
Map<String, Object?> navigateAnswer({
  String url = 'https://example.com/docs/start',
  String title = 'Getting started',
  Map<String, Object?> extra = const {},
}) => {'success': true, 'url': url, 'title': title, ...extra};

ToolCall navigateCall(
  Object? answer, {
  Map<String, Object?>? args = const {'url': 'https://example.com/docs/start'},
  ToolCallStatus status = ToolCallStatus.completed,
}) => ToolCall(
  name: 'browser_navigate',
  summary: '',
  args: args,
  resultData: answer,
  status: status,
);

/// A `web_extract` page that was read.
Map<String, Object?> extractedPage(String url, String title, String content) =>
    {'url': url, 'title': title, 'content': content};

ToolCall extractCall(
  Object? answer, {
  Map<String, Object?>? args = const {
    'urls': ['https://example.com/a', 'https://example.org/b'],
  },
  ToolCallStatus status = ToolCallStatus.completed,
}) => ToolCall(
  name: 'web_extract',
  summary: '',
  args: args,
  resultData: answer,
  status: status,
);
