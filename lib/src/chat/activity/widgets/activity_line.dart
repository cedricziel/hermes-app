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
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: _size.value,
          child: _Line(model: model, onOpen: widget.onOpen),
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
    final twoRows = scaler.scale(1) >= kActivityLineTwoRowScale;
    final sentenceLine = scaler.scale(_kSentenceSize) * 1.3;
    final chipLine = scaler.scale(_kChipSize) * 1.25 + 6;
    final minHeight = platformChromeOf(context).isApple
        ? kAppleMinTapTarget
        : 48.0;
    final natural = twoRows
        ? _kPadding * 2 + sentenceLine + 4 + chipLine
        : _kPadding * 2 + sentenceLine;
    final height = natural < minHeight ? minHeight : natural;

    final sentence = Text(
      model.sentence,
      key: const Key('activity-line-sentence'),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: _kSentenceSize,
        height: 1.3,
        color: theme.colorScheme.onSurface,
      ),
    );
    final indicatorSize = scaler.scale(16).clamp(16.0, 24.0);
    final indicator = model.busy
        ? WorkingIndicator(size: indicatorSize)
        : SizedBox(width: indicatorSize);
    final chips = [
      for (final counter in model.counters)
        _ActivityCounterChip(counter: counter),
    ];
    final spoken = [for (final counter in model.counters) counter.label];

    return Semantics(
      container: true,
      button: true,
      label: spoken.isEmpty
          ? l10n.chatActivityLineLabel(model.sentence)
          : l10n.chatActivityLineLabelCounters(
              model.sentence,
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
                  child: twoRows
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                indicator,
                                const SizedBox(width: 10),
                                Expanded(child: sentence),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: EdgeInsets.only(
                                left: indicatorSize + 10,
                              ),
                              child: SizedBox(
                                height: chipLine,
                                // A counter is scaled down to fit rather than
                                // cut when the text size leaves too little
                                // width.
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(children: _spaced(chips)),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            indicator,
                            const SizedBox(width: 10),
                            Expanded(child: sentence),
                            if (chips.isNotEmpty) const SizedBox(width: 8),
                            ..._spaced(chips),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _spaced(List<Widget> chips) => [
  for (var i = 0; i < chips.length; i++) ...[
    if (i > 0) const SizedBox(width: 6),
    chips[i],
  ],
];

/// A small rounded chip: an icon naming what is counted and the count. Private
/// to the line, plain markup on tokens.
class _ActivityCounterChip extends StatelessWidget {
  const _ActivityCounterChip({required this.counter});

  final ActivityLineCounter counter;

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
      counter.text,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: _kChipSize,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
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
