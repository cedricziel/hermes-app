import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/sources/turn_sources.dart';

import 'support/link_tool_fixtures.dart';
import 'support/sources_fixtures.dart';

List<String> _addresses(Iterable<ToolCall> calls) => [
  for (final source in collectTurnSources(calls)) source.address,
];

void main() {
  group('order', () {
    test('a page that was opened comes first, search hits follow', () {
      final sources = collectTurnSources([
        searchCall([
          for (final n in [1, 2, 3, 4, 5]) searchHit('https://example.com/$n'),
        ]),
        extractCall(
          {
            'results': [extractedPage('https://example.com/2', 'Two', 'text')],
          },
          args: const {
            'urls': ['https://example.com/2'],
          },
        ),
      ]);

      expect(
        [for (final s in sources) s.address],
        [
          for (final n in [2, 1, 3, 4, 5]) 'https://example.com/$n',
        ],
      );
    });

    test('each group keeps the order its pages were first seen in', () {
      final calls = [
        searchCall([
          searchHit('https://a.test/'),
          searchHit('https://b.test/'),
        ]),
        navigateCall(navigateAnswer(url: 'https://d.test/', title: 'D')),
        navigateCall(navigateAnswer(url: 'https://c.test/', title: 'C')),
      ];

      expect(_addresses(calls), [
        'https://d.test/',
        'https://c.test/',
        'https://a.test/',
        'https://b.test/',
      ]);
    });
  });

  group('de-duplication', () {
    test(
      'Example.com/a#x and example.com/a are one page, first title wins',
      () {
        final sources = collectTurnSources([
          searchCall([
            searchHit('https://Example.com/a#x', title: 'First title'),
            searchHit('https://example.com/a', title: 'Second title'),
          ]),
          navigateCall(
            navigateAnswer(url: 'https://example.com/a', title: 'Third title'),
          ),
        ]);

        expect(sources, hasLength(1));
        expect(sources.single.title, 'First title');
        expect(sources.single.address, 'https://Example.com/a#x');
      },
    );

    test('a default port and a root slash are dropped, the query is kept', () {
      expect(
        _addresses([
          searchCall([
            searchHit('https://example.com:443/'),
            searchHit('https://example.com'),
            searchHit('http://example.com:80/p?q=1'),
            searchHit('http://example.com/p?q=2'),
            searchHit('http://example.com/p?q=1#frag'),
          ]),
        ]),
        [
          'https://example.com:443/',
          'http://example.com:80/p?q=1',
          'http://example.com/p?q=2',
        ],
      );
    });

    test('a different path or a different port is another page', () {
      expect(
        _addresses([
          searchCall([
            searchHit('https://example.com/a'),
            searchHit('https://example.com/a/'),
            searchHit('https://example.com:8443/a'),
          ]),
        ]),
        hasLength(3),
      );
    });
  });

  group('what counts', () {
    test(
      'credentials, other schemes and unreadable addresses are left out',
      () {
        expect(
          _addresses([
            searchCall([
              searchHit('https://user:secret@example.com/'),
              searchHit('https://:secret@example.com/'),
              searchHit('https:\\\\user:secret@example.com/'),
              searchHit('ftp://files.example.com/a'),
              searchHit('javascript:alert(1)'),
              searchHit('data:text/html,hi'),
              searchHit('example.com/no-scheme'),
              searchHit('https://good.example/'),
            ]),
          ]),
          ['https://good.example/'],
        );
      },
    );

    test('browser_snapshot and the other browser tools add nothing', () {
      expect(
        _addresses([
          ToolCall(
            name: 'browser_snapshot',
            summary: '',
            resultData: {
              'success': true,
              'url': 'https://example.com/snap',
              'snapshot': '- link "x"',
            },
          ),
          ToolCall(
            name: 'browser_get_images',
            summary: '',
            resultData: {
              'success': true,
              'url': 'https://example.com/images',
              'images': <Object>[],
            },
          ),
        ]),
        isEmpty,
      );
    });

    test(
      'an errored web_extract page adds nothing, a good one beside it does',
      () {
        expect(
          _addresses([
            extractCall({
              'results': [
                {'url': 'https://bad.example/', 'error': 'blocked'},
                extractedPage('https://good.example/', 'Good', 'text'),
              ],
            }),
          ]),
          ['https://good.example/'],
        );
      },
    );

    test('a web_extract that failed as a whole adds nothing', () {
      expect(
        _addresses([
          extractCall({'error': 'no key'}),
          extractCall(null, status: ToolCallStatus.running),
        ]),
        isEmpty,
      );
    });

    test('a browser_navigate that did not succeed adds nothing', () {
      expect(
        _addresses([
          navigateCall({'success': false, 'error': 'timeout'}),
          navigateCall({'url': 'https://example.com/x'}),
          navigateCall(null, status: ToolCallStatus.running),
        ]),
        isEmpty,
      );
    });

    test('a result held as JSON text reads like decoded data', () {
      final sources = collectTurnSources([
        ToolCall(
          name: 'web_search',
          summary: '',
          result: '{"success": true, "data": {"web": [{"url": "https://a.test/", "title": "A"}]}}',
        ),
      ]);

      expect([for (final s in sources) s.address], ['https://a.test/']);
    });

    test('no calls, other tools and a search with no hits give no source', () {
      expect(collectTurnSources(const []), isEmpty);
      expect(
        collectTurnSources([
          const ToolCall(name: 'terminal', summary: 'ls'),
          searchCall(const []),
        ]),
        isEmpty,
      );
    });
  });

  group('titles', () {
    test('a missing title is the host', () {
      final sources = collectTurnSources([
        searchCall([
          searchHit('https://example.com/a', title: null),
          searchHit('https://example.org/b', title: '  '),
        ]),
      ]);

      expect(
        [for (final s in sources) s.title],
        ['example.com', 'example.org'],
      );
      expect([for (final s in sources) s.host], ['example.com', 'example.org']);
    });

    test('a later title fills a missing first one', () {
      final sources = collectTurnSources([
        searchCall([searchHit('https://example.com/a', title: null)]),
        navigateCall(
          navigateAnswer(url: 'https://example.com/a', title: 'The page'),
        ),
      ]);

      expect(sources.single.title, 'The page');
    });

    test('a title is one line and at most 120 characters', () {
      final sources = collectTurnSources([
        searchCall([
          searchHit('https://example.com/a', title: 'Line one\n  line   two'),
          searchHit('https://example.com/b', title: 'x' * 300),
        ]),
      ]);

      expect(sources[0].title, 'Line one line two');
      expect(sources[1].title.characters.length, 120);
    });
  });
}
