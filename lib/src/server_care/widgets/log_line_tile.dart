import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../log_line.dart';
import 'log_level_chip.dart';

/// Continuation lines shown before the rest fold behind "Show N more lines".
const int kLogContinuationFoldAfter = 3;

/// One log entry: the time and a level chip, the source in small monospace,
/// then the message in monospace. Continuation lines (a traceback) sit under
/// it behind a left rule and fold after three. Everything is selectable.
///
/// An entry whose header could not be read has no [time], [level] or
/// [source]; its [message] is the raw line.
class LogLineTile extends StatefulWidget {
  const LogLineTile({
    super.key,
    this.time,
    this.level,
    this.source,
    required this.message,
    this.continuation = const [],
  });

  final String? time;
  final LogLevel? level;
  final String? source;
  final String message;
  final List<String> continuation;

  @override
  State<LogLineTile> createState() => _LogLineTileState();
}

class _LogLineTileState extends State<LogLineTile> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = context.hermesColors.subtleText;
    final time = widget.time;
    final level = widget.level;
    final source = widget.source;
    final lines = widget.continuation;
    final folded = !_showAll && lines.length > kLogContinuationFoldAfter;
    final shown = folded ? lines.take(kLogContinuationFoldAfter) : lines;
    final hidden = lines.length - kLogContinuationFoldAfter;
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: scheme.onSurface,
    );
    final minTarget = platformChromeOf(context) == PlatformChrome.material
        ? 48.0
        : kAppleMinTapTarget;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            if (time != null || level != null)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (time != null)
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 13,
                        color: muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  if (level != null) LogLevelChip(level: level),
                ],
              ),
            if (source != null)
              SelectableText(
                source,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: muted,
                ),
              ),
            SelectableText(widget.message, style: mono),
            if (lines.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(color: scheme.outline, width: 2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in shown)
                            SelectableText(line, style: mono),
                          if (folded)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size(0, minTarget),
                                  padding: EdgeInsets.zero,
                                  // The theme has no link colour; primary is
                                  // what an action is set in.
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                                onPressed: () =>
                                    setState(() => _showAll = true),
                                child: Text(
                                  context.l10n.serverCareLogShowMoreLines(
                                    hidden,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A day's label ("Today", "12 Nov") over its entries. Pinned while its
/// entries scroll under it.
class LogDayHeader extends StatelessWidget {
  const LogDayHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            header: true,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sliver with a pinned [LogDayHeader] followed by [itemCount] entries.
/// The header measures itself, so it grows with the text size.
class LogDaySection extends StatelessWidget {
  const LogDaySection({
    super.key,
    required this.label,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String label;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final header = LogDayHeader(label: label);
    return SliverMainAxisGroup(
      slivers: [
        SliverResizingHeader(
          minExtentPrototype: header,
          maxExtentPrototype: header,
          child: header,
        ),
        SliverList.builder(itemCount: itemCount, itemBuilder: itemBuilder),
      ],
    );
  }
}
