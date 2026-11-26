import 'package:hermes_app/src/chat/chat_models.dart';

// The `web_search` result shape as Hermes builds it at d923a5eb
// (`tools/web_tools.py`: `{success, data: {web: [{url, title, description}]}}`),
// read from its source, not recorded; the contract PR that records the real
// bodies replaces it.

/// One hit of a `web_search`; a null [title] leaves the key out.
Map<String, Object?> searchHit(
  String url, {
  String? title = 'A page',
  String description = 'About the page.',
}) => {'url': url, 'title': ?title, 'description': description};

ToolCall searchCall(
  List<Map<String, Object?>> hits, {
  ToolCallStatus status = ToolCallStatus.completed,
}) => ToolCall(
  name: 'web_search',
  summary: 'a query',
  args: const {'query': 'a query'},
  status: status,
  resultData: {
    'success': true,
    'data': {'web': hits},
  },
);
