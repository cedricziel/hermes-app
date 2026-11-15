import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/hermes_theme.dart';
import 'disclosure_tile.dart';
import 'grouped_list.dart';

/// A disclosure row that opens lines of command output, in monospace in a
/// tinted box. Closed unless [initiallyOpen]. The caller words every text.
///
/// The lines are selectable unless [selectable] is false, which also keeps
/// them out of an ancestor's selection area. With [capHeight] the box is at
/// most 320 pt or 40 percent of the window tall, whichever is less, and
/// scrolls inside itself beyond that, with a scrollbar that stays visible on
/// desktop; without it the box grows with its lines. With [maxLines] only the
/// last lines show, and [earlierLabel] (required then, and for
/// [earlierLines]) says how many came before them (plus [earlierLines], which
/// the caller already left out) in a muted line of its own above the box's
/// lines, outside their scroll area. A [footnote] sits under the
/// box. With [blank] the box holds no lines, only the muted [blankNote]. The
/// lines run left to right in any locale.
class OutputLinesTile extends StatefulWidget {
  const OutputLinesTile({
    super.key,
    required this.label,
    required this.lines,
    this.initiallyOpen = false,
    this.selectable = true,
    this.maxLines,
    this.earlierLines = 0,
    this.earlierLabel,
    this.footnote,
    this.blank = false,
    this.blankNote,
    this.semanticsLabel,
    this.capHeight = false,
  }) : assert(maxLines == null || maxLines >= 0),
       assert(
         (maxLines == null && earlierLines == 0) || earlierLabel != null,
         'Dropped lines need an earlierLabel to say so.',
       );

  final String label;
  final List<String> lines;
  final bool initiallyOpen;
  final bool selectable;
  final int? maxLines;
  final int earlierLines;
  final String Function(int count)? earlierLabel;
  final String? footnote;
  final bool blank;
  final String? blankNote;

  /// Read in place of [label], for a name with the line count.
  final String? semanticsLabel;

  /// Limits the box to 320 pt or 40 percent of the window height and scrolls
  /// inside it.
  final bool capHeight;

  @override
  State<OutputLinesTile> createState() => _OutputLinesTileState();
}

class _OutputLinesTileState extends State<OutputLinesTile> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final cap = widget.maxLines;
    final dropped = cap != null && widget.lines.length > cap
        ? widget.lines.length - cap
        : 0;
    final shown = dropped == 0 ? widget.lines : widget.lines.sublist(dropped);
    final earlier = widget.earlierLines + dropped;
    final earlierLabel = widget.earlierLabel;
    final earlierNote = earlier > 0 && earlierLabel != null
        ? earlierLabel(earlier)
        : null;
    final text = shown.join('\n');
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: metrics.footerSize,
      color: scheme.onSurface,
    );
    final maxHeight = math.min(320.0, MediaQuery.sizeOf(context).height * 0.4);
    final Widget body = SizedBox(
      width: double.infinity,
      child: widget.selectable
          ? SelectableText(text, style: style, textDirection: TextDirection.ltr)
          : SelectionContainer.disabled(
              child: Text(text, style: style, textDirection: TextDirection.ltr),
            ),
    );
    final title = Text(
      widget.label,
      style: TextStyle(fontSize: metrics.titleSize),
    );
    return DisclosureTile(
      initiallyExpanded: widget.initiallyOpen,
      shape: const Border(),
      collapsedShape: const Border(),
      minTileHeight: metrics.rowMinHeight,
      tilePadding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
      childrenPadding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        0,
        metrics.rowPadding,
        metrics.rowPadding,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: widget.semanticsLabel == null
          ? title
          : Semantics(
              label: widget.semanticsLabel,
              child: ExcludeSemantics(child: title),
            ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: widget.blank
                ? Text(
                    widget.blankNote ?? '',
                    style: TextStyle(
                      fontSize: metrics.footerSize,
                      color: muted,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (earlierNote != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            earlierNote,
                            style: TextStyle(
                              fontSize: metrics.footerSize,
                              color: muted,
                            ),
                          ),
                        ),
                      if (widget.capHeight)
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxHeight),
                            child: Scrollbar(
                              controller: _scroll,
                              thumbVisibility: desktop,
                              child: SingleChildScrollView(
                                controller: _scroll,
                                child: body,
                              ),
                            ),
                          ),
                        )
                      else
                        body,
                    ],
                  ),
          ),
        ),
        if (widget.footnote != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.footnote!,
              style: TextStyle(fontSize: metrics.footerSize, color: muted),
            ),
          ),
      ],
    );
  }
}
