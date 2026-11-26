import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/src/chat/page_link.dart';
import 'package:hermes_app/src/chat/sources/turn_sources.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/page_press_menu.dart';
import 'package:hermes_app/src/chat/widgets/sources_row.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _pages = [
  ('Release notes for November', 'news.example.net'),
  ('Getting started with Example', 'docs.example.com'),
  ('How the new settings screen works', 'blog.example.org'),
  ('Example Cloud pricing', 'example.com'),
  ('Why faster start-up matters', 'engineering.example.io'),
  ('Changelog', 'github.com'),
  ('Frequently asked questions', 'support.example.com'),
];

List<TurnSource> _sources(int count) => [
  for (final (title, host) in _pages.take(count))
    TurnSource(address: 'https://$host/page', title: title, host: host),
];

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

void _noOpen(Uri _) {}

/// A row that keeps whether it is expanded, as the chat's does.
class _Interactive extends StatefulWidget {
  const _Interactive(this.sources, {this.expanded = false});

  final List<TurnSource> sources;
  final bool expanded;

  @override
  State<_Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<_Interactive> {
  late var _expanded = widget.expanded;

  @override
  Widget build(BuildContext context) => SourcesRow(
    sources: widget.sources,
    expanded: _expanded,
    onExpandedChanged: (value) => setState(() => _expanded = value),
    onOpen: _noOpen,
  );
}

/// A row with its first chip's press menu open: the menu opens on the first
/// frame, where a long press would put it.
class _MenuOpen extends StatefulWidget {
  const _MenuOpen();

  @override
  State<_MenuOpen> createState() => _MenuOpenState();
}

class _MenuOpenState extends State<_MenuOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final source = _sources(1).single;
      showPagePressMenu(
        context,
        pagePressActions(
          context,
          PageLink.parse(source.address),
          onOpen: _noOpen,
        ),
        const Offset(120, 120),
        source.host,
      );
    });
  }

  @override
  Widget build(BuildContext context) => _Interactive(_sources(7));
}

Widget _row(List<TurnSource> sources, {double width = 393}) =>
    frame(_Interactive(sources), maxWidth: width);

Widget _under(List<TurnSource> sources) => frame(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('The release added a faster start and a new settings scr'),
      const SizedBox(height: 12),
      _Interactive(sources),
      MessageActions(text: 'The release added', stopped: true, onRetry: () {}),
    ],
  ),
  maxWidth: 393,
);

WidgetbookNode sourcesRowNode() => WidgetbookFolder(
  name: 'Sources row',
  children: [
    WidgetbookComponent(
      name: 'SourcesRow',
      useCases: [
        WidgetbookUseCase(
          name: 'One source',
          builder: (_) => _row(_sources(1)),
        ),
        WidgetbookUseCase(
          name: 'Three sources',
          builder: (_) => _row(_sources(3)),
        ),
        WidgetbookUseCase(
          name: 'Seven, collapsed',
          builder: (_) => _row(_sources(7)),
        ),
        WidgetbookUseCase(
          name: 'Seven, expanded',
          builder: (_) =>
              frame(_Interactive(_sources(7), expanded: true), maxWidth: 393),
        ),
        WidgetbookUseCase(
          name: 'Long titles',
          builder: (_) => _row([
            TurnSource(
              address: 'https://docs.example.com/page',
              title:
                  'A very long title that goes on and on about the many things '
                  'this page covers, far more than a chip can hold',
              host: 'docs.example.com',
            ),
            TurnSource(
              address: 'https://example.org/page',
              title: 'Supercalifragilisticexpialidocious' * 3,
              host: 'example.org',
            ),
          ]),
        ),
        WidgetbookUseCase(
          name: 'A bare host',
          builder: (_) => _row(const [
            TurnSource(
              address: 'https://status.example.com/',
              title: 'status.example.com',
              host: 'status.example.com',
            ),
            TurnSource(
              address:
                  'https://a-rather-long-sub-domain.documentation.example.com/',
              title: 'a-rather-long-sub-domain.documentation.example.com',
              host: 'a-rather-long-sub-domain.documentation.example.com',
            ),
          ]),
        ),
        WidgetbookUseCase(
          name: 'A title with a bidirectional override',
          builder: (_) => _row([
            TurnSource(
              address: 'https://download.example.com/',
              title: 'Report ${String.fromCharCode(0x202E)}gnp.exe',
              host: 'download.example.com',
            ),
          ]),
        ),
        WidgetbookUseCase(
          name: 'Under a stopped reply',
          builder: (_) => _under(_sources(4)),
        ),
        WidgetbookUseCase(
          name: 'Press menu open',
          builder: (_) => frame(const _MenuOpen(), maxWidth: 393),
        ),
        ...onEachPlatform('Seven, collapsed', (_) => _row(_sources(7))),
        ...onEachPlatform(
          'Seven, expanded',
          (_) =>
              frame(_Interactive(_sources(7), expanded: true), maxWidth: 393),
        ),
        WidgetbookUseCase(
          name: 'Narrow Mac window',
          builder: (_) => _row(_sources(7), width: 320),
        ),
        WidgetbookUseCase(
          name: 'Wide window',
          builder: (_) => _row(_sources(7), width: 720),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(3, _row(_sources(5), width: 390)),
        ),
        WidgetbookUseCase(
          name: 'German',
          builder: (_) => Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('de'),
              child: _row(_sources(7)),
            ),
          ),
        ),
      ],
    ),
  ],
);
