import 'chat_models.dart';
import 'tool_result.dart';

/// One hit of a web search.
typedef WebSearchHit = ({String? title, String url, String description});

/// The hits of a `web_search` call, a hit without a title having a null one;
/// null for a result that is not the shape Hermes answers.
List<WebSearchHit>? webSearchHits(ToolCall call) {
  if (toolResultMap(call) case {'data': {'web': final List web}}) {
    return [
      for (final hit in web)
        if (hit case {'url': final String url})
          (
            title: hit['title'] is String ? hit['title'] as String : null,
            url: url,
            description: hit['description'] is String
                ? hit['description'] as String
                : '',
          ),
    ];
  }
  return null;
}
