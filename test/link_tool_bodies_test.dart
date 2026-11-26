import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/link_preview_card.dart';
import 'package:hermes_app/src/chat/widgets/link_tool_bodies.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:material_ui/material_ui.dart';

import 'support/link_tool_fixtures.dart';
import 'support/pump_on_platform.dart';

Future<void> _pump(WidgetTester tester, ToolCall call) => pumpOnPlatform(
  tester,
  SingleChildScrollView(child: ToolCallCard(call: call, initiallyOpen: true)),
  platform: TargetPlatform.android,
);

List<LinkPreviewCard> _cards(WidgetTester tester) =>
    tester.widgetList<LinkPreviewCard>(find.byType(LinkPreviewCard)).toList();

/// Counts the HTTP clients the code under test creates.
class _CountingHttp extends HttpOverrides {
  var clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    throw StateError('A card must not make a request.');
  }
}

void main() {
  group('browser_navigate', () {
    testWidgets('shows one card and what the page offers', (tester) async {
      await _pump(
        tester,
        navigateCall(
          navigateAnswer(
            extra: {'element_count': 86, 'snapshot': '- link "Home" [ref=e1]'},
          ),
        ),
      );
      expect(_cards(tester).single.title, 'Getting started');
      expect(_cards(tester).single.address, 'https://example.com/docs/start');
      expect(find.text('86 interactive elements on the page'), findsOne);
      expect(find.text('Page snapshot'), findsOneWidget);
      expect(find.textContaining('[ref=e1]'), findsNothing);
      await tester.tap(find.text('Page snapshot'));
      await tester.pumpAndSettle();
      expect(find.textContaining('[ref=e1]', findRichText: true), findsOne);
    });

    testWidgets('says so when the site may block automated visitors', (
      tester,
    ) async {
      await _pump(
        tester,
        navigateCall(
          navigateAnswer(
            extra: {'bot_detection_warning': 'Cloudflare challenge seen.'},
          ),
        ),
      );
      expect(find.text('This page may block automated visitors.'), findsOne);
      expect(find.text('Cloudflare challenge seen.'), findsOneWidget);
    });

    testWidgets('keeps the card of the address a failed call asked for', (
      tester,
    ) async {
      await _pump(
        tester,
        navigateCall({'success': false, 'error': 'net::ERR_NAME_NOT_RESOLVED'}),
      );
      final card = _cards(tester).single;
      expect(card.state, LinkPreviewState.failed);
      expect(card.address, 'https://example.com/docs/start');
      expect(find.text("Couldn't open this page."), findsOneWidget);
      expect(find.text('net::ERR_NAME_NOT_RESOLVED'), findsOneWidget);
    });

    testWidgets('a running call shows the host and Opening…', (tester) async {
      await _pump(tester, navigateCall(null, status: ToolCallStatus.running));
      expect(_cards(tester).single.state, LinkPreviewState.running);
      expect(find.text('Opening…'), findsOneWidget);
    });

    test('falls back for a result that is not the expected shape', () {
      for (final answer in <Object?>[
        <String, Object?>{},
        {'success': 'yes'},
        {'title': 'No success flag', 'url': 'https://example.com/'},
        'plain text',
        [1, 2],
      ]) {
        expect(
          LinkToolBody.navigate(navigateCall(answer)),
          isNull,
          reason: '$answer',
        );
      }
      expect(
        LinkToolBody.navigate(navigateCall(navigateAnswer(url: ''), args: {})),
        isNull,
      );
    });

    test('a JSON text in the result is read as well as resultData', () {
      expect(
        LinkToolBody.navigate(
          ToolCall(
            name: 'browser_navigate',
            summary: '',
            result: '{"success": true, "url": "https://example.com/"}',
          ),
        ),
        isNotNull,
      );
    });
  });

  group('web_extract', () {
    testWidgets('three pages, one unreadable', (tester) async {
      await _pump(
        tester,
        extractCall({
          'results': [
            extractedPage('https://example.com/a', 'A', 'First   page\n\ntext'),
            {
              'url': 'https://example.org/b',
              'title': 'B',
              'content': '',
              'error': 'Blocked by robots.txt',
            },
            extractedPage('https://example.net/c', 'C', 'x' * 400),
          ],
        }),
      );
      final cards = _cards(tester);
      expect(cards.map((card) => card.state), [
        LinkPreviewState.ready,
        LinkPreviewState.failed,
        LinkPreviewState.ready,
      ]);
      expect(find.text('First page text'), findsOneWidget);
      expect(find.text("Couldn't read this page."), findsOneWidget);
      expect(find.text('Blocked by robots.txt'), findsOneWidget);
      expect(cards[2].excerpt.length, lessThanOrEqualTo(160));
    });

    testWidgets('a call that failed as a whole fails every page it asked for', (
      tester,
    ) async {
      await _pump(tester, extractCall({'error': 'No API key'}));
      expect(_cards(tester).map((card) => card.address), [
        'https://example.com/a',
        'https://example.org/b',
      ]);
      expect(find.text("Couldn't read this page."), findsNWidgets(2));
    });

    testWidgets('no pages is said', (tester) async {
      await _pump(tester, extractCall({'results': <Object?>[]}));
      expect(find.text('No pages'), findsOneWidget);
      expect(find.byType(LinkPreviewCard), findsNothing);
    });

    testWidgets('a running call shows a card per asked page', (tester) async {
      await _pump(tester, extractCall(null, status: ToolCallStatus.running));
      expect(_cards(tester), hasLength(2));
      expect(find.text('Reading…'), findsNWidgets(2));
    });

    test('falls back for a result that is not the expected shape', () {
      for (final answer in <Object?>[
        <String, Object?>{},
        {'results': 'none'},
        {
          'results': [1, 'two'],
        },
        {'success': true},
      ]) {
        expect(
          LinkToolBody.extract(extractCall(answer)),
          isNull,
          reason: '$answer',
        );
      }
    });
  });

  testWidgets('rendering the cards makes no request', (tester) async {
    final http = _CountingHttp();
    final before = HttpOverrides.current;
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = before);

    for (final call in [
      navigateCall(navigateAnswer(extra: {'snapshot': 'tree'})),
      navigateCall({'success': false, 'error': 'refused'}),
      extractCall({
        'results': [
          extractedPage('https://example.com/a', 'A', 'text'),
          extractedPage('https://user:secret@example.com/b', 'B', 'text'),
          extractedPage('ftp://files.example.com/c', 'C', 'text'),
          extractedPage('javascript:alert(1)', 'D', 'text'),
          extractedPage('http://[::1]:8080/e', 'E', 'text'),
        ],
      }),
    ]) {
      await _pump(tester, call);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(http.clients, 0);
  });

  testWidgets('the registry serves both tools', (tester) async {
    for (final call in [
      navigateCall(navigateAnswer()),
      extractCall({
        'results': [extractedPage('https://example.com/a', 'A', 'text')],
      }),
    ]) {
      await _pump(tester, call);
      expect(find.byType(LinkToolBody), findsOneWidget);
      expect(find.text('Result'), findsNothing);
    }
  });
}
