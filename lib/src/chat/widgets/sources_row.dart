import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart' show safePathText;
import '../../telemetry/breadcrumbs.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../context/widgets/context_format.dart' show contextLargeText;
import '../page_link.dart';
import '../sources/turn_sources.dart';
import 'link_tool_bodies.dart' show launchPage;
import 'page_press_menu.dart';

/// Chips a collapsed row shows on a phone, and on a window wide enough for
/// more, before "+N more". At the largest text sizes two show, one a line.
const _phoneChips = 3;
const _wideChips = 4;
const _largeTextChips = 2;
const _wideWidth = 560.0;

/// The widest a chip grows in a wide window before its title ends in an
/// ellipsis.
const _wideChipWidth = 300.0;

/// The space between chips.
const _gap = 8.0;

/// The pages a reply drew on, as a row of chips under it: a monogram tile, the
/// title and the host of each. A tap opens a page in the system browser; a
/// long press or a right click offers Open in browser and Copy link. A plain
/// model: nothing is requested from the pages' hosts, not even an icon, and
/// every title is untrusted text shown through [safePathText].
class SourcesRow extends StatelessWidget {
  const SourcesRow({
    super.key,
    required this.sources,
    this.expanded = false,
    this.onExpandedChanged,
    this.onOpen,
  });

  final List<TurnSource> sources;

  /// Whether every source shows, rather than the first few and "+N more".
  final bool expanded;

  /// The "+N more" chip asks for `true`, "Show fewer" for `false`.
  final ValueChanged<bool>? onExpandedChanged;

  /// Opens a web address; null leaves the chips without a tap.
  final ValueChanged<Uri>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final large = contextLargeText(context);
    final oneLine = _chipShape(context).oneLine;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.chatWidgetsSourcesSemantics(sources.length),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final shown = large
              ? _largeTextChips
              : available >= _wideWidth
              ? _wideChips
              : _phoneChips;
          final hidden = sources.length - shown;
          // Two chips share a line on a phone; a wide window gives each a
          // fixed width. The largest text, and a Mac chip that has one line
          // for a title and a host, take a line of their own when narrow.
          final maxWidth = large || (oneLine && available < _wideWidth)
              ? available
              : available < _wideWidth
              ? (available - _gap) / 2
              : _wideChipWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(
                  l10n.chatWidgetsSourcesHeader(sources.length),
                  style: Theme.of(context).textTheme.labelSmall!
                      .copyWith(fontWeight: FontWeight.w600, color: subtle),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final source in expanded ? sources : sources.take(shown))
                    _SourceChip(
                      source: source,
                      maxWidth: maxWidth,
                      onOpen: onOpen,
                    ),
                  if (hidden > 0)
                    _ExpandChip(
                      label: expanded
                          ? l10n.chatWidgetsSourcesFewer
                          : l10n.chatWidgetsSourcesMore(hidden),
                      onTap: onExpandedChanged == null
                          ? null
                          : () => onExpandedChanged!(!expanded),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// [SourcesRow] for a reply in the chat: it keeps whether the row is
/// expanded, opens a page in the system browser and notes the two on the
/// breadcrumb trail, with a count and nothing of the pages.
class ReplySources extends StatefulWidget {
  const ReplySources({
    super.key,
    required this.sources,
    this.open = launchPage,
  });

  final List<TurnSource> sources;

  /// Opens a web address; the system browser by default.
  final ValueChanged<Uri> open;

  @override
  State<ReplySources> createState() => _ReplySourcesState();
}

class _ReplySourcesState extends State<ReplySources> {
  bool _expanded = false;

  Breadcrumbs get _breadcrumbs {
    try {
      return context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      return Breadcrumbs.none;
    }
  }

  @override
  Widget build(BuildContext context) => SourcesRow(
    sources: widget.sources,
    expanded: _expanded,
    onExpandedChanged: (expanded) {
      setState(() => _expanded = expanded);
      if (expanded) {
        _breadcrumbs('chat.sources.expanded', {'count': widget.sources.length});
      }
    },
    onOpen: (uri) {
      _breadcrumbs('chat.sources.opened', {'count': widget.sources.length});
      widget.open(uri);
    },
  );
}

/// What sets a chip's height and layout: 44 on iOS, 48 on the Material
/// platforms, and a line of 32 on a Mac.
({double height, bool oneLine}) _chipShape(BuildContext context) =>
    platformChromeOf(context) == PlatformChrome.macos
    ? (height: 32, oneLine: true)
    : (
        height: minTapTargetOf(context, desktop: kMaterialMinTapTarget),
        oneLine: false,
      );

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.source,
    required this.maxWidth,
    required this.onOpen,
  });

  final TurnSource source;
  final double maxWidth;
  final ValueChanged<Uri>? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final subtle = context.hermesColors.subtleText;
    final oneLine = _chipShape(context).oneLine;
    final link = PageLink.parse(source.address);
    final uri = link.uri;
    final open = uri != null && onOpen != null ? () => onOpen!(uri) : null;
    final actions = pagePressActions(context, link, onOpen: onOpen);
    final title = safePathText(source.title);
    final host = safePathText(source.host);
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.bodySmall!.copyWith(fontWeight: FontWeight.w600),
    );
    final hostText = Text(
      host,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.labelSmall!.copyWith(
        fontWeight: FontWeight.w400,
        color: subtle,
      ),
    );
    final label = oneLine
        // The host is laid out first, so only the title gives way.
        ? Row(
            children: [
              Flexible(child: titleText),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth * 0.6),
                child: hostText,
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleText, hostText],
          );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Semantics(
        container: true,
        button: true,
        focusable: true,
        excludeSemantics: true,
        label: l10n.chatWidgetsSourcesChipLabel(title, host),
        onTap: open,
        customSemanticsActions: {
          for (final action in actions)
            CustomSemanticsAction(label: action.label): action.run,
        },
        child: _Chip(
          onTap: open,
          onMenu: (at) => showPagePressMenu(context, actions, at, host),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PageTile(letter: link.monogram, size: 28),
              const SizedBox(width: 8),
              Flexible(child: label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandChip extends StatelessWidget {
  const _ExpandChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    excludeSemantics: true,
    label: label,
    onTap: onTap,
    child: _Chip(
      onTap: onTap,
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.onTap, required this.child, this.onMenu});

  final VoidCallback? onTap;
  final ValueChanged<Offset>? onMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = 10.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: FocusRing(
            radius: radius,
            child: InkWell(
              onTap: onTap,
              onLongPress: onMenu == null
                  ? null
                  : () => onMenu!(centreOf(context)),
              onSecondaryTapUp: onMenu == null
                  ? null
                  : (details) => onMenu!(details.globalPosition),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: _chipShape(context).height,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: Center(widthFactor: 1, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
