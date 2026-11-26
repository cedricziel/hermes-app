import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../chat_models.dart';
import '../page_link.dart';
import '../tool_result.dart';
import '../web_search_result.dart';

/// The longest title a source keeps; the chip ends it in an ellipsis.
const kSourceTitleChars = 120;

/// A page a reply drew on, for the row of sources under it.
@immutable
class TurnSource {
  const TurnSource({
    required this.address,
    required this.title,
    required this.host,
  });

  /// The address as it was first seen, which a tap opens. It is an `http` or
  /// `https` address without credentials.
  final String address;

  /// What the web called the page, on one line and capped; the host when it
  /// gave none. Untrusted: show it through `safePathText`.
  final String title;

  /// The host as the address wrote it, for display.
  final String host;

  @override
  bool operator ==(Object other) =>
      other is TurnSource &&
      other.address == address &&
      other.title == title &&
      other.host == host;

  @override
  int get hashCode => Object.hash(address, title, host);
}

/// The distinct pages the [calls] of one turn drew on: pages the agent opened
/// (`web_extract` pages without an error, `browser_navigate` results that
/// succeeded) first, then `web_search` hits not already listed, each group in
/// the order its pages were first seen. Only `http` and `https` addresses
/// without credentials count; other tools add nothing.
///
/// [calls] are those of the whole turn, from the last prompt to the reply: a
/// reply read from history is several assistant rows.
List<TurnSource> collectTurnSources(Iterable<ToolCall> calls) {
  // By normal form, in the order each page was first seen.
  final pages = <String, _Page>{};
  // Pages opened, in the order each was first opened.
  final opened = <String>{};

  void add(String address, String? title, {required bool wasOpened}) {
    final link = PageLink.parse(address);
    final uri = link.uri;
    if (uri == null) return;
    final key = _normalForm(uri);
    final page = pages.putIfAbsent(key, () => _Page(address.trim(), link.host));
    if (page.title.isEmpty && title != null) page.title = _oneLine(title);
    if (wasOpened) opened.add(key);
  }

  for (final call in calls) {
    if (call.preparing) continue;
    switch (call.name) {
      case 'web_search':
        for (final hit in webSearchHits(call) ?? const <WebSearchHit>[]) {
          add(hit.url, hit.title, wasOpened: false);
        }
      case 'web_extract':
        if (toolResultMap(call)?['results'] case final List results) {
          for (final row in results) {
            if (row is! Map || _text(row['error']).isNotEmpty) continue;
            add(_text(row['url']), _text(row['title']), wasOpened: true);
          }
        }
      case 'browser_navigate':
        final result = toolResultMap(call);
        if (result == null ||
            result['success'] != true ||
            _text(result['error']).isNotEmpty) {
          continue;
        }
        final reported = _text(result['url']);
        add(
          reported.isNotEmpty ? reported : _text(call.args?['url']),
          _text(result['title']),
          wasOpened: true,
        );
    }
  }

  return [
    for (final key in [
      ...opened,
      ...pages.keys.where((k) => !opened.contains(k)),
    ])
      TurnSource(
        address: pages[key]!.address,
        title: pages[key]!.title.isEmpty ? pages[key]!.host : pages[key]!.title,
        host: pages[key]!.host,
      ),
  ];
}

/// A page while its sources are collected: the first title that is not empty
/// wins.
class _Page {
  _Page(this.address, this.host);

  final String address;
  final String host;
  String title = '';
}

/// Two addresses of one page read the same: scheme and host in lower case, a
/// default port and the root's slash dropped, the fragment dropped, the query
/// kept. (`Uri` lower-cases the scheme and host itself.)
String _normalForm(Uri uri) {
  final defaultPort = uri.scheme == 'https' ? 443 : 80;
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return '${uri.scheme}://$host'
      '${uri.port == defaultPort ? '' : ':${uri.port}'}'
      '${uri.path == '/' ? '' : uri.path}'
      '${uri.hasQuery ? '?${uri.query}' : ''}';
}

String _text(Object? value) => value is String ? value.trim() : '';

final _whitespace = RegExp(r'\s+');

String _oneLine(String title) => title
    .replaceAll(_whitespace, ' ')
    .trim()
    .characters
    .take(kSourceTitleChars)
    .toString();
