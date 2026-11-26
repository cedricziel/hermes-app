import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoActionSheet;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/sources/turn_sources.dart';
import 'package:hermes_app/src/chat/widgets/sources_row.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/pump_on_platform.dart';
import 'support/recorded_breadcrumbs.dart';

List<TurnSource> _sources(int count, {String title = 'Page'}) => [
  for (var n = 1; n <= count; n++)
    TurnSource(
      address: 'https://site$n.example/page',
      title: '$title $n',
      host: 'site$n.example',
    ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  TargetPlatform platform = TargetPlatform.android,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  await pumpOnPlatform(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.topLeft, child: row),
      ),
    ),
    platform: platform,
  );
  tester.view.physicalSize = size;
  await tester.pump();
}

Finder _chip(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(InkWell));

/// A row that keeps whether it is expanded, as the chat's does.
class _Host extends StatefulWidget {
  const _Host(this.sources, this.opened);

  final List<TurnSource> sources;
  final List<Uri> opened;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) => SourcesRow(
    sources: widget.sources,
    expanded: _expanded,
    onExpandedChanged: (value) => setState(() => _expanded = value),
    onOpen: widget.opened.add,
  );
}

class _CountingHttp extends HttpOverrides {
  var clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    throw StateError('A source row must not make a request.');
  }
}

void main() {
  group('opening a source', () {
    testWidgets('a tap opens the address and makes no other request', (
      tester,
    ) async {
      final http = _CountingHttp();
      final before = HttpOverrides.current;
      HttpOverrides.global = http;
      addTearDown(() => HttpOverrides.global = before);
      final opened = <Uri>[];
      await _pump(tester, SourcesRow(sources: _sources(2), onOpen: opened.add));

      await tester.tap(find.text('Page 2'));
      await tester.pump(const Duration(seconds: 1));

      expect(opened, [Uri.parse('https://site2.example/page')]);
      expect(http.clients, 0);
    });

    testWidgets('a long press offers Open in browser and Copy link', (
      tester,
    ) async {
      final opened = <Uri>[];
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester, SourcesRow(sources: _sources(1), onOpen: opened.add));

      await tester.longPress(find.text('Page 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Page 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in browser'));
      await tester.pumpAndSettle();

      expect(copied, ['https://site1.example/page']);
      expect(opened, [Uri.parse('https://site1.example/page')]);
    });

    testWidgets('the press menu is an action sheet on iOS', (tester) async {
      await _pump(
        tester,
        SourcesRow(sources: _sources(1), onOpen: (_) {}),
        platform: TargetPlatform.iOS,
      );

      await tester.longPress(find.text('Page 1'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Open in browser'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
    });
  });

  group('the chips', () {
    testWidgets('seven sources on a phone show three and "+4 more"', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(tester, _Host(_sources(7), opened));

      expect(find.text('Sources · 7'), findsOneWidget);
      for (final n in [1, 2, 3]) {
        expect(find.text('Page $n'), findsOneWidget);
      }
      expect(find.text('Page 4'), findsNothing);
      expect(find.text('+4 more'), findsOneWidget);

      await tester.tap(find.text('+4 more'));
      await tester.pump();

      for (final n in [1, 2, 3, 4, 5, 6, 7]) {
        expect(find.text('Page $n'), findsOneWidget);
      }
      expect(find.text('Show fewer'), findsOneWidget);
      expect(find.text('+4 more'), findsNothing);
      expect(opened, isEmpty, reason: 'expanding opens nothing');

      await tester.tap(find.text('Show fewer'));
      await tester.pump();
      expect(find.text('Page 4'), findsNothing);
      expect(find.text('+4 more'), findsOneWidget);
    });

    testWidgets('a desktop window shows four', (tester) async {
      await _pump(
        tester,
        _Host(_sources(7), []),
        platform: TargetPlatform.macOS,
        size: const Size(900, 700),
      );

      expect(find.text('Page 4'), findsOneWidget);
      expect(find.text('Page 5'), findsNothing);
      expect(find.text('+3 more'), findsOneWidget);
    });

    testWidgets('as many sources as fit have no "+N more"', (tester) async {
      await _pump(tester, _Host(_sources(3), []));

      expect(find.text('Sources · 3'), findsOneWidget);
      expect(find.textContaining('more'), findsNothing);
      expect(find.text('Show fewer'), findsNothing);
    });

    testWidgets('one source reads "Source"', (tester) async {
      await _pump(tester, _Host(_sources(1), []));

      expect(find.text('Source'), findsOneWidget);
    });

    testWidgets('at the largest text size two show, a line each', (
      tester,
    ) async {
      await _pump(tester, _Host(_sources(5), []), textScale: 2);

      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Page 3'), findsNothing);
      expect(find.text('+3 more'), findsOneWidget);
      expect(
        tester.getSize(_chip('Page 1')).width,
        tester.getSize(_chip('Page 2')).width,
      );
      expect(tester.getSize(_chip('Page 1')).width, greaterThan(300));
    });

    testWidgets('no sources draw nothing', (tester) async {
      await _pump(tester, const SourcesRow(sources: []));

      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(SourcesRow)), Size.zero);
    });
  });

  group('a long title', () {
    testWidgets('ends in an ellipsis and the host stays whole on a Mac', (
      tester,
    ) async {
      await _pump(
        tester,
        SourcesRow(
          sources: [
            TurnSource(
              address: 'https://doc.test/guide',
              title: 'A very long title ' * 12,
              host: 'doc.test',
            ),
          ],
          onOpen: (_) {},
        ),
        platform: TargetPlatform.macOS,
        size: const Size(900, 700),
      );

      RenderParagraph paragraph(Finder finder) =>
          tester.renderObject<RenderParagraph>(finder);
      expect(
        paragraph(find.textContaining('A very long title')).didExceedMaxLines,
        isTrue,
      );
      expect(paragraph(find.text('doc.test')).didExceedMaxLines, isFalse);
    });

    testWidgets('and its host are two lines on a phone', (tester) async {
      await _pump(
        tester,
        SourcesRow(
          sources: [
            TurnSource(
              address: 'https://docs.example.org/guide',
              title: 'A very long title ' * 12,
              host: 'docs.example.org',
            ),
          ],
        ),
        platform: TargetPlatform.iOS,
      );

      expect(
        tester.getTopLeft(find.text('docs.example.org')).dy,
        greaterThan(
          tester.getTopLeft(find.textContaining('A very long title')).dy,
        ),
      );
    });
  });

  testWidgets(
    'a title with a bidirectional override is drawn as a placeholder',
    (tester) async {
      await _pump(
        tester,
        SourcesRow(
          sources: [
            TurnSource(
              address: 'https://site.example/',
              title: 'Safe ${String.fromCharCode(0x202E)}gnp.exe',
              host: 'site.example',
            ),
          ],
        ),
      );

      expect(find.textContaining('<U+202E>'), findsOneWidget);
      expect(find.textContaining(String.fromCharCode(0x202E)), findsNothing);
    },
  );

  group('hit targets', () {
    for (final (platform, height) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.windows, 48.0),
      (TargetPlatform.linux, 48.0),
      (TargetPlatform.macOS, 32.0),
    ]) {
      testWidgets('are $height high on $platform', (tester) async {
        await _pump(
          tester,
          SourcesRow(sources: _sources(5), onOpen: (_) {}),
          platform: platform,
        );

        expect(tester.getSize(_chip('Page 1')).height, height);
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: find.text('+2 more'),
                  matching: find.byType(InkWell),
                ),
              )
              .height,
          height,
        );
      });
    }
  });

  group('for a screen reader', () {
    testWidgets('the row is "Sources, N" and a chip is "title, host"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, SourcesRow(sources: _sources(7), onOpen: (_) {}));

      expect(find.bySemanticsLabel('Sources, 7'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 1, site1.example'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Page 1, site1.example')),
        matchesSemantics(
          label: 'Page 1, site1.example',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          customActions: const [
            CustomSemanticsAction(label: 'Open in browser'),
            CustomSemanticsAction(label: 'Copy link'),
          ],
        ),
      );
      handle.dispose();
    });
  });

  group('the breadcrumbs of a reply\'s row', () {
    testWidgets('carry a count and nothing of the pages', (tester) async {
      final trail = RecordedBreadcrumbs();
      final opened = <Uri>[];
      await pumpOnPlatform(
        tester,
        Provider<Breadcrumbs>.value(
          value: trail.breadcrumbs,
          child: ReplySources(sources: _sources(5), open: opened.add),
        ),
        platform: TargetPlatform.android,
      );

      await tester.tap(find.text('+2 more'));
      await tester.pump();
      await tester.tap(find.text('Page 4'));
      await tester.pump();

      expect(trail.named('chat.sources.expanded'), [
        {'count': 5},
      ]);
      expect(trail.named('chat.sources.opened'), [
        {'count': 5},
      ]);
      expect(trail.all, hasLength(2));
      expect(trail.text, isNot(contains('site')));
      expect(opened, [Uri.parse('https://site4.example/page')]);
    });
  });
}
