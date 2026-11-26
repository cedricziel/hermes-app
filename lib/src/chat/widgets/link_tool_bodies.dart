import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/disclosure_tile.dart';
import '../chat_models.dart';
import '../report_chat_bug.dart';
import '../tool_result.dart';
import 'code_tool_body.dart' show CodeNote, CodeNoteTone, CodeNoteView;
import 'link_preview_card.dart';
import 'tool_value_view.dart';

/// The most pages `web_extract` takes in one call.
const _maxPages = 5;

/// How much of a page's text an extracted page's card quotes.
const _excerptChars = 160;

/// How much of a page's text is read to find those characters.
const _excerptScan = 1000;

/// One page of a call, as the parser read it.
typedef LinkToolPage = ({
  String address,
  String title,
  String excerpt,
  LinkPreviewState state,
  String error,
});

/// What an opened `browser_navigate` or `web_extract` call shows: a card for
/// each page the agent opened, and under them what the tool said about the
/// page. Each parser answers null for a result that is not the shape it
/// expects, which leaves the card its generic input and result.
class LinkToolBody extends StatelessWidget {
  const LinkToolBody({
    super.key,
    required this.pages,
    required this.opening,
    this.elementCount,
    this.warnings,
    this.snapshot = '',
    this.snapshotOpen = false,
  });

  final List<LinkToolPage> pages;

  /// Whether the browser opened the pages ("Opening…") rather than Hermes
  /// reading their text ("Reading…").
  final bool opening;

  /// `browser_navigate`: how many elements of the page can be used.
  final int? elementCount;

  /// The server's words when the tool warned that the page may block
  /// automated visitors; null when it did not.
  final List<String>? warnings;

  /// `browser_navigate`: the page as the text the agent saw.
  final String snapshot;

  /// Whether the snapshot's disclosure starts open.
  final bool snapshotOpen;

  /// `browser_navigate`: the page it opened, from the result's own title and
  /// address (the call's address when the result has none).
  static Widget? navigate(ToolCall call) =>
      (_navigated[call] ??= _Cached(_navigate(call))).body;

  static final _navigated = Expando<_Cached>();
  static final _extracted = Expando<_Cached>();

  static LinkToolBody? _navigate(ToolCall call) {
    if (call.preparing) return null;
    final asked = _string(call.args?['url']);
    final result = toolResultMap(call);
    if (result == null) {
      return call.resultData == null &&
              call.result.isEmpty &&
              call.status == ToolCallStatus.running &&
              asked.isNotEmpty
          ? LinkToolBody(pages: [_running(asked)], opening: true)
          : null;
    }
    final error = _string(result['error']);
    final failed = result['success'] == false || error.isNotEmpty;
    if (!failed && result['success'] != true) return null;
    final reported = _string(result['url']);
    final address = reported.isNotEmpty ? reported : asked;
    if (address.isEmpty) return null;
    if (failed) {
      return LinkToolBody(pages: [_failed(address, error)], opening: true);
    }
    final flagged = [
      for (final key in const ['bot_detection_warning', 'stealth_warning'])
        if (result[key] == true || _string(result[key]).isNotEmpty) key,
    ];
    return LinkToolBody(
      pages: [
        (
          address: address,
          title: _string(result['title']),
          excerpt: '',
          state: LinkPreviewState.ready,
          error: '',
        ),
      ],
      opening: true,
      elementCount: result['element_count'] is int
          ? result['element_count'] as int
          : null,
      warnings: flagged.isEmpty
          ? null
          : [
              for (final key in flagged)
                if (_string(result[key]).isNotEmpty) _string(result[key]),
            ],
      snapshot: _string(result['snapshot']),
    );
  }

  /// `web_extract`: a card per page, with the start of its text. A page with
  /// an `error` is a card that does not open.
  static Widget? extract(ToolCall call) =>
      (_extracted[call] ??= _Cached(_extract(call))).body;

  static LinkToolBody? _extract(ToolCall call) {
    if (call.preparing) return null;
    final asked = [
      if (call.args?['urls'] case final List urls)
        for (final url in urls)
          if (url is String && url.trim().isNotEmpty) url,
    ].take(_maxPages);
    final result = toolResultMap(call);
    if (result == null) {
      return call.resultData == null &&
              call.result.isEmpty &&
              call.status == ToolCallStatus.running &&
              asked.isNotEmpty
          ? LinkToolBody(
              pages: [for (final url in asked) _running(url)],
              opening: false,
            )
          : null;
    }
    if (result['results'] case final List results) {
      final pages = <LinkToolPage>[
        for (final row
            in results
                .where((row) => row is Map && _string(row['url']).isNotEmpty)
                .take(_maxPages))
          if (row is Map)
            (
              address: _string(row['url']),
              title: _string(row['title']),
              excerpt: _excerpt(_string(row['content'])),
              state: _string(row['error']).isEmpty
                  ? LinkPreviewState.ready
                  : LinkPreviewState.failed,
              error: _string(row['error']),
            ),
      ];
      return pages.isEmpty && results.isNotEmpty
          ? null
          : LinkToolBody(pages: pages, opening: false);
    }
    final error = _string(result['error']);
    if (error.isEmpty || asked.isEmpty) return null;
    return LinkToolBody(
      pages: [for (final url in asked) _failed(url, error)],
      opening: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pages.isEmpty)
            Text(
              l10n.chatWidgetsLinkNoPages,
              style: Theme.of(context).textTheme.labelSmall!
                  .copyWith(color: subtle),
            ),
          for (final (index, page) in pages.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            LinkPreviewCard(
              address: page.address,
              title: page.title,
              excerpt: page.excerpt.characters.take(_excerptChars).toString(),
              state: page.state,
              runningLabel: opening
                  ? l10n.chatWidgetsLinkOpening
                  : l10n.chatWidgetsLinkReading,
              notes: [
                if (page.state == LinkPreviewState.failed)
                  CodeNote(
                    CodeNoteTone.error,
                    opening
                        ? l10n.chatWidgetsLinkCouldntOpen
                        : l10n.chatWidgetsLinkCouldntRead,
                    detail: page.error,
                  ),
              ],
              onOpen: _launch,
            ),
          ],
          if (elementCount != null)
            CodeNoteView(
              CodeNote(
                CodeNoteTone.info,
                l10n.chatWidgetsLinkElements(elementCount!),
              ),
            ),
          if (warnings != null)
            CodeNoteView(
              CodeNote(
                CodeNoteTone.warning,
                l10n.chatWidgetsLinkBotWarning,
                detail: warnings!.join('\n'),
              ),
            ),
          if (snapshot.isNotEmpty)
            DisclosureTile(
              title: Text(
                l10n.chatWidgetsLinkSnapshot,
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(fontWeight: FontWeight.w600, color: subtle),
              ),
              initiallyExpanded: snapshotOpen,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedAlignment: Alignment.topLeft,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: ToolValuePanel.maxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: ToolValueView(text: snapshot),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The start of a page's text on one line: the card shows [_excerptChars] of
/// it, so a long page is not scanned to the end.
String _excerpt(String content) =>
    (content.length > _excerptScan
            ? content.substring(0, _excerptScan)
            : content)
        .replaceAll(RegExp(r'\s+'), ' ');

/// The parse of a call, kept: the card asks on every build, closed ones too.
class _Cached {
  const _Cached(this.body);

  final LinkToolBody? body;
}

LinkToolPage _running(String address) => (
  address: address,
  title: '',
  excerpt: '',
  state: LinkPreviewState.running,
  error: '',
);

LinkToolPage _failed(String address, String error) => (
  address: address,
  title: '',
  excerpt: '',
  state: LinkPreviewState.failed,
  error: error,
);

String _string(Object? value) => value is String ? value.trim() : '';

Future<void> _launch(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (error, stack) {
    reportChatBug(error, stack, 'a page link');
  }
}
