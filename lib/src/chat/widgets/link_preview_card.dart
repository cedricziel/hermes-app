import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart' show safePathText;
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/busy_bar.dart';
import '../page_link.dart';
import 'code_tool_body.dart' show CodeNote, CodeNoteTone, CodeNoteView;
import 'page_press_menu.dart';

/// Where a page stands: [ready] with its text, [running] while the tool still
/// works on it, or [failed].
enum LinkPreviewState { ready, running, failed }

/// A page the agent opened, as one card: a tile with the host's first letter,
/// the title, the host and path and an excerpt. The whole card is one button
/// that opens the address in the system browser, for an `http` or `https`
/// address with no credentials; a long press or a right click offers Open in
/// browser and Copy link. A plain model: the card never requests anything
/// from the page's host, not even an icon.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    required this.address,
    this.title = '',
    this.excerpt = '',
    this.state = LinkPreviewState.ready,
    this.runningLabel = '',
    this.notes = const [],
    this.onOpen,
  });

  /// The address as the tool named it; [PageLink] decides what it allows.
  final String address;

  /// The page's title, as the web sent it. The host stands in when it is empty.
  final String title;
  final String excerpt;
  final LinkPreviewState state;

  /// "Opening…" or "Reading…", for a page that has not answered.
  final String runningLabel;

  /// What went wrong, for a failed page.
  final List<CodeNote> notes;

  /// Opens a web address; null leaves the card without a tap.
  final ValueChanged<Uri>? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final subtle = context.hermesColors.subtleText;
    final link = PageLink.parse(address);
    final ready = state == LinkPreviewState.ready;
    final uri = link.uri;
    final openable = ready && uri != null && onOpen != null;
    final shownTitle = _oneLine(title);
    final actions = ready
        ? pagePressActions(context, link, onOpen: onOpen)
        : const <PagePressAction>[];
    final excerptText = _oneLine(excerpt);
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageTile(letter: link.monogram, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shownTitle.isEmpty ? safePathText(link.host) : shownTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      if (shownTitle.isNotEmpty)
                        TextSpan(
                          text: safePathText(link.host),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      TextSpan(text: safePathText(link.path)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall!.copyWith(
                    fontWeight: FontWeight.w400,
                    color: subtle,
                  ),
                ),
                if (excerptText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      excerptText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                if (state == LinkPreviewState.running)
                  _Running(label: runningLabel),
                for (final note in notes) CodeNoteView(note),
                if (ready && !link.opens)
                  CodeNoteView(
                    CodeNote(
                      CodeNoteTone.info,
                      link.kind == PageLinkKind.withCredentials
                          ? l10n.chatWidgetsLinkNotOpenedCredentials
                          : l10n.chatWidgetsLinkNotOpened,
                    ),
                  ),
              ],
            ),
          ),
          if (openable) ...[
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: AppIcon(AppIcons.openExternal, size: 16, color: subtle),
            ),
          ],
        ],
      ),
    );
    final card = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: actions.isEmpty
            ? content
            : Material(
                color: Colors.transparent,
                child: FocusRing(
                  radius: 10,
                  child: InkWell(
                    onTap: openable ? () => onOpen!(uri) : null,
                    onLongPress: () => showPagePressMenu(
                      context,
                      actions,
                      centreOf(context),
                      safePathText(link.host),
                    ),
                    onSecondaryTapUp: (details) => showPagePressMenu(
                      context,
                      actions,
                      details.globalPosition,
                      safePathText(link.host),
                    ),
                    child: content,
                  ),
                ),
              ),
      ),
    );
    return Semantics(
      container: true,
      button: openable,
      customSemanticsActions: {
        for (final action in actions)
          CustomSemanticsAction(label: action.label): action.run,
      },
      child: card,
    );
  }
}

/// Text from the web on one line: whitespace collapsed, and made safe to show.
String _oneLine(String text) =>
    safePathText(text.replaceAll(RegExp(r'\s+'), ' ').trim());

class _Running extends StatelessWidget {
  const _Running({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            fontWeight: FontWeight.w400,
            color: context.hermesColors.subtleText,
          ),
        ),
        const SizedBox(height: 4),
        const BusyBar(minHeight: 2),
      ],
    ),
  );
}
