import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../../../widgets/busy_bar.dart' show reduceMotionOf;
import 'activity_line_model.dart';
import 'working_indicator.dart';

/// The text scale from which the line has two rows: the sentence over the
/// counters.
const double kActivityLineTwoRowScale = 1.5;

const double _kSentenceSize = 14;
const double _kChipSize = 12;
const double _kPadding = 8;

/// One button under the chat header that says what Hermes is doing and opens
/// the Activity panel.
///
/// A plain-model widget: pass null while nothing is working and the line
/// folds away with a short size transition (none with reduced motion), so the
/// transcript does not jump on every sentence change. The height is constant
/// for a text scale: a touch target (44 pt on Apple platforms, 48 dp
/// elsewhere), and two rows from [kActivityLineTwoRowScale].
class ActivityLine extends StatefulWidget {
  const ActivityLine({super.key, required this.model, required this.onOpen});

  final ActivityLineModel? model;
  final VoidCallback onOpen;

  @override
  State<ActivityLine> createState() => _ActivityLineState();
}

class _ActivityLineState extends State<ActivityLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _size = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: widget.model == null ? 0 : 1,
  );

  /// Kept while the line folds away, so it does not go blank first.
  ActivityLineModel? _last;

  @override
  void initState() {
    super.initState();
    _last = widget.model;
  }

  @override
  void didUpdateWidget(ActivityLine old) {
    super.didUpdateWidget(old);
    final model = widget.model;
    if (model != null) _last = model;
    if (model != null && old.model == null) {
      reduceMotionOf(context) ? _size.value = 1 : _size.forward();
    } else if (model == null && old.model != null) {
      reduceMotionOf(context) ? _size.value = 0 : _size.reverse();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _size,
    builder: (context, _) {
      final model = _last;
      if (model == null || (widget.model == null && _size.value == 0)) {
        return const SizedBox.shrink();
      }
      Widget line = _Line(model: model, onOpen: widget.onOpen);
      if (widget.model == null) {
        // Folding away: no taps, nothing for a screen reader.
        line = IgnorePointer(child: ExcludeSemantics(child: line));
      }
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: _size.value,
          child: line,
        ),
      );
    },
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.model, required this.onOpen});

  final ActivityLineModel model;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final twoRows =
        scaler.scale(_kSentenceSize) / _kSentenceSize >=
        kActivityLineTwoRowScale;
    // From text scale 2 the sentence may use two lines, so a long one is not
    // cut to a few words; the height is that of two lines at that scale.
    final sentenceLines = scaler.scale(_kSentenceSize) / _kSentenceSize >= 2
        ? 2
        : 1;
    final sentenceLine = scaler.scale(_kSentenceSize) * 1.3;
    final chipLine = scaler.scale(_kChipSize) * 1.25 + 6;
    final minHeight = platformChromeOf(context).isApple
        ? kAppleMinTapTarget
        : 48.0;
    final natural = twoRows
        ? _kPadding * 2 + sentenceLine * sentenceLines + 4 + chipLine
        : _kPadding * 2 + sentenceLine;
    final height = natural < minHeight ? minHeight : natural;

    final sentenceStyle = DefaultTextStyle.of(context).style.merge(
      theme.textTheme.bodyMedium?.copyWith(
        fontSize: _kSentenceSize,
        height: 1.3,
        color: theme.colorScheme.onSurface,
      ),
    );
    final sentence = Text(
      model.sentence,
      key: const Key('activity-line-sentence'),
      maxLines: sentenceLines,
      softWrap: sentenceLines > 1,
      overflow: TextOverflow.ellipsis,
      style: sentenceStyle,
    );
    final indicatorSize = scaler.scale(16).clamp(16.0, 24.0);
    final indicator = SizedBox(
      width: indicatorSize,
      height: sentenceLine,
      child: model.busy
          ? Center(child: WorkingIndicator(size: indicatorSize))
          : null,
    );
    final spoken = [for (final counter in model.counters) counter.label];

    Widget body() {
      if (twoRows) {
        final chips = [
          for (final counter in model.counters)
            _ActivityCounterChip(counter: counter),
        ];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                indicator,
                const SizedBox(width: 10),
                Expanded(child: sentence),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: indicatorSize + 10),
              child: SizedBox(
                height: chipLine,
                // A counter is scaled down to fit rather than cut when the
                // text size leaves too little width.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(children: _spaced(chips)),
                ),
              ),
            ),
          ],
        );
      }
      return LayoutBuilder(
        builder: (context, box) {
          final chips = _fitChips(
            context,
            model.counters,
            sentence: model.sentence,
            sentenceStyle: sentenceStyle,
            room: box.maxWidth - indicatorSize - 10,
          );
          return Row(
            children: [
              indicator,
              const SizedBox(width: 10),
              Expanded(child: sentence),
              if (chips.isNotEmpty) const SizedBox(width: _kChipsGap),
              ..._spaced(chips),
            ],
          );
        },
      );
    }

    return Semantics(
      container: true,
      button: true,
      label: spoken.isEmpty
          ? l10n.chatActivityLineLabel(model.spokenSentence)
          : l10n.chatActivityLineLabelCounters(
              model.spokenSentence,
              spoken.join(', '),
            ),
      onTap: onOpen,
      child: ExcludeSemantics(
        child: Material(
          key: const Key('activity-line'),
          color: theme.colorScheme.surfaceContainerHighest,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: InkWell(
              onTap: onOpen,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(alignment: Alignment.centerLeft, child: body()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _kChipsGap = 8;
const double _kBetweenChips = 6;

/// The chips for one row, so the sentence stays readable beside them: all with
/// their words when the whole sentence still fits, else all compact (icon and
/// number), else only the one that changed last (the first), words first, then
/// compact. The last resort is used when nothing fits.
List<Widget> _fitChips(
  BuildContext context,
  List<ActivityLineCounter> counters, {
  required String sentence,
  required TextStyle sentenceStyle,
  required double room,
}) {
  if (counters.isEmpty) return const [];
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final chipStyle = _chipStyle(context);

  double measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  // Icon, gap, horizontal padding and border of a chip, besides its text.
  final chrome = scaler.scale(13) + 3 + 14 + 2;
  double widthOf(List<(ActivityLineCounter, bool)> chips) =>
      _kChipsGap +
      _kBetweenChips * (chips.length - 1) +
      [
        for (final (counter, compact) in chips)
          chrome +
              measure(compact ? counter.compactText : counter.text, chipStyle),
      ].fold(0.0, (sum, width) => sum + width);

  final first = counters.first;
  final options = [
    [for (final counter in counters) (counter, false)],
    [for (final counter in counters) (counter, true)],
    if (counters.length > 1) ...[
      [(first, false)],
      [(first, true)],
    ],
  ];
  final sentenceWidth = measure(sentence, sentenceStyle).ceilToDouble();
  final pick = options.firstWhere(
    (option) => sentenceWidth + widthOf(option) <= room,
    orElse: () => options.last,
  );
  return [
    for (final (counter, compact) in pick)
      _ActivityCounterChip(counter: counter, compact: compact),
  ];
}

TextStyle _chipStyle(BuildContext context) =>
    DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: _kChipSize,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );

List<Widget> _spaced(List<Widget> chips) => [
  for (var i = 0; i < chips.length; i++) ...[
    if (i > 0) const SizedBox(width: 6),
    chips[i],
  ],
];

/// A small rounded chip: an icon naming what is counted and the count. Private
/// to the line, plain markup on tokens.
class _ActivityCounterChip extends StatelessWidget {
  const _ActivityCounterChip({required this.counter, this.compact = false});

  final ActivityLineCounter counter;

  /// Icon and number only.
  final bool compact;

  static AppIconSet _icon(ActivityCounterKind kind) => switch (kind) {
    ActivityCounterKind.plan => AppIcons.checklist,
    ActivityCounterKind.processes => AppIcons.terminal,
    ActivityCounterKind.references => AppIcons.hub,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final text = Text(
      compact ? counter.compactText : counter.text,
      maxLines: 1,
      softWrap: false,
      style: _chipStyle(context),
    );
    final chip = DecoratedBox(
      key: Key('activity-chip-${counter.kind.name}'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              _icon(counter.kind),
              size: scaler.scale(13),
              color: context.hermesColors.subtleText,
            ),
            const SizedBox(width: 3),
            text,
          ],
        ),
      ),
    );
    return chip;
  }
}
