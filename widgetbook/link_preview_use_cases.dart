import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/code_tool_body.dart';
import 'package:hermes_app/src/chat/widgets/link_preview_card.dart';
import 'package:hermes_app/src/chat/widgets/link_tool_bodies.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/link_tool_fixtures.dart';
import 'frame.dart';

const _page = 'https://docs.example.com/guide/getting-started?lang=en';
const _excerpt =
    'Install the command line tool, sign in once, and run the first command '
    'to see your project. This guide takes about five minutes and needs no '
    'account beyond the one you already have.';

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

void _noOpen(Uri _) {}

Widget _card({
  String address = _page,
  String title = 'Getting started with Example',
  String excerpt = _excerpt,
  LinkPreviewState state = LinkPreviewState.ready,
  List<CodeNote> notes = const [],
  double width = 420,
}) => frame(
  LinkPreviewCard(
    address: address,
    title: title,
    excerpt: excerpt,
    state: state,
    runningLabel: 'Opening…',
    notes: notes,
    onOpen: _noOpen,
  ),
  maxWidth: width,
);

Widget _tool(ToolCall call, {double width = 480}) =>
    frame(ToolCallCard(call: call, initiallyOpen: true), maxWidth: width);

ToolCall _extract() => extractCall({
  'results': [
    extractedPage('https://docs.example.com/guide', 'The guide', _excerpt),
    {
      'url': 'https://blog.example.org/post/42',
      'title': 'A post',
      'content': '',
      'error': 'The page needs a login.',
    },
    extractedPage(
      'https://news.example.net/2026/11/release-notes',
      'Release notes for November',
      'What changed: faster start, fewer crashes, a new settings screen.',
    ),
  ],
});

WidgetbookNode linkPreviewNode() => WidgetbookFolder(
  name: 'Link previews',
  children: [
    WidgetbookComponent(
      name: 'LinkPreviewCard',
      useCases: [
        WidgetbookUseCase(name: 'Page', builder: (_) => _card()),
        ...onEachPlatform('Page', (_) => _card()),
        WidgetbookUseCase(
          name: 'Failed',
          builder: (_) => _card(
            state: LinkPreviewState.failed,
            excerpt: '',
            notes: const [
              CodeNote(
                CodeNoteTone.error,
                "Couldn't read this page.",
                detail: 'The page needs a login.',
              ),
            ],
          ),
        ),
        WidgetbookUseCase(
          name: 'Running',
          builder: (_) =>
              _card(state: LinkPreviewState.running, title: '', excerpt: ''),
        ),
        WidgetbookUseCase(
          name: 'Long title',
          builder: (_) => _card(
            title:
                'A very long title that goes on and on about the many things '
                'this page covers, so it cannot fit on two lines of a phone',
            width: 340,
          ),
        ),
        WidgetbookUseCase(
          name: 'Long address',
          builder: (_) => _card(
            address:
                'https://a-very-long-sub-domain.documentation.example.com/'
                'section/with/many/nested/folders/and-a-long-page-name.html'
                '?utm_source=newsletter&utm_campaign=a-long-campaign-name',
            width: 340,
          ),
        ),
        WidgetbookUseCase(
          name: 'No spaces in a title',
          builder: (_) => _card(
            title: 'Supercalifragilisticexpialidocious' * 3,
            width: 340,
          ),
        ),
        WidgetbookUseCase(
          name: 'Another scheme',
          builder: (_) => _card(address: 'ftp://files.example.com/a.txt'),
        ),
        WidgetbookUseCase(
          name: 'Credentials in the address',
          builder: (_) =>
              _card(address: 'https://user:secret@example.com/private/area'),
        ),
        WidgetbookUseCase(
          name: 'German',
          builder: (_) =>
              _german(_card(address: 'ftp://files.example.com/a.txt')),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(3, _card(width: 390)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'LinkToolBody',
      useCases: [
        WidgetbookUseCase(
          name: 'browser_navigate: page',
          builder: (_) => _tool(
            navigateCall(
              navigateAnswer(
                url: _page,
                title: 'Getting started with Example',
                extra: {'element_count': 86, 'snapshot': '- link "Home"'},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'browser_navigate: page with a warning',
          builder: (_) => _tool(
            navigateCall(
              navigateAnswer(
                url: _page,
                extra: {
                  'element_count': 3,
                  'bot_detection_warning': 'The site served a challenge page; results may be partial.',
                },
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'browser_navigate: snapshot open',
          builder: (_) => frame(
            const LinkToolBody(
              pages: [
                (
                  address: _page,
                  title: 'Getting started with Example',
                  excerpt: '',
                  state: LinkPreviewState.ready,
                  error: '',
                ),
              ],
              opening: true,
              elementCount: 12,
              snapshot:
                  '- heading "Getting started" [level=1]\n'
                  '- link "Home" [ref=e1]\n'
                  '- button "Sign in" [ref=e2]',
              snapshotOpen: true,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'browser_navigate: failed',
          builder: (_) => _tool(
            navigateCall(
              {'success': false, 'error': 'net::ERR_NAME_NOT_RESOLVED'},
              args: const {'url': 'https://does-not-exist.example/'},
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'browser_navigate: running',
          builder: (_) =>
              _tool(navigateCall(null, status: ToolCallStatus.running)),
        ),
        WidgetbookUseCase(
          name: 'web_extract: three pages, one unreadable',
          builder: (_) => _tool(_extract()),
        ),
        WidgetbookUseCase(
          name: 'web_extract: no pages',
          builder: (_) => _tool(extractCall({'results': <Object?>[]})),
        ),
        ...onEachPlatform(
          'web_extract: three pages, one unreadable',
          (_) => _tool(_extract()),
        ),
        WidgetbookUseCase(
          name: 'web_extract: German',
          builder: (_) => _german(_tool(_extract())),
        ),
        WidgetbookUseCase(
          name: 'web_extract: largest text',
          builder: (_) => _scaled(3, _tool(_extract(), width: 390)),
        ),
      ],
    ),
  ],
);
