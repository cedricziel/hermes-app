import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/busy_bar.dart';
import 'usage_format.dart';

enum UsageChartMetric { tokens, cost }

/// The window a chart shows. Only [days90] scrolls sideways.
enum UsageChartWindow {
  days7(7),
  days30(30),
  days90(90);

  const UsageChartWindow(this.days);

  final int days;

  bool get scrolls => this == days90;
}

/// One bar: a calendar day, its value in the chart's metric (tokens, or
/// dollars) and how many conversations it held.
class UsageChartDay {
  const UsageChartDay({
    required this.day,
    required this.value,
    this.conversations = 0,
  });

  final DateTime day;
  final double value;
  final int conversations;
}

/// Width from which the chart has the desktop height.
const double _wideChartWidth = 480;
const double _minBarTarget = 44;

double usageChartHeightFor(double width) =>
    width >= _wideChartWidth ? 240 : 180;

/// From this text scale the x labels go and the y labels stop growing.
bool _isAccessibilityTextScale(TextScaler scaler) =>
    scaler.scale(16) / 16 >= 1.5;

String _valueText(AppLocalizations l10n, UsageChartMetric metric, double v) =>
    metric == UsageChartMetric.tokens
    ? formatTokens(l10n, v)
    : formatDollars(l10n, v);

String _valueSpoken(AppLocalizations l10n, UsageChartMetric metric, double v) =>
    metric == UsageChartMetric.tokens
    ? formatTokensSpoken(l10n, v)
    : formatDollars(l10n, v);

String _summary(
  AppLocalizations l10n,
  List<UsageChartDay> days,
  UsageChartMetric metric,
  UsageChartWindow window,
) {
  final head = l10n.serverCareUsageChartHead(
    metric.name,
    l10n.serverCareUsageLastDays(window.days),
  );
  final total = days.fold<double>(0, (sum, d) => sum + d.value);
  if (total <= 0) return '$head ${l10n.serverCareUsageChartNoUsage}';
  var top = days.first;
  for (final d in days) {
    if (d.value > top.value) top = d;
  }
  String spoken(double v) => metric == UsageChartMetric.tokens
      ? formatCompactSpoken(l10n, v)
      : formatDollars(l10n, v);
  return '$head ${l10n.serverCareUsageChartTotalHighest(spoken(total), spoken(top.value), formatDayLong(l10n, top.day))}';
}

/// A vertical bar chart of one value per day, drawn in-repo so its
/// semantics, text scaling and motion stay under our control.
///
/// Takes plain values: the page maps its report onto [UsageChartDay]. The
/// newest day is selected at first; press and drag, hover, a tap or the
/// arrow keys move the selection, and the label above the chart follows it.
class UsageChart extends StatefulWidget {
  const UsageChart({
    super.key,
    required this.days,
    required this.metric,
    required this.window,
    this.initialSelectedIndex,
    this.onSelected,
    this.height,
  });

  /// In date order, oldest first, one per day of [window].
  final List<UsageChartDay> days;
  final UsageChartMetric metric;
  final UsageChartWindow window;

  /// The bar selected first; the newest day when null.
  final int? initialSelectedIndex;
  final ValueChanged<int>? onSelected;

  /// 180 on a phone and 240 from [_wideChartWidth] wide when null.
  final double? height;

  @override
  State<UsageChart> createState() => _UsageChartState();
}

class _UsageChartState extends State<UsageChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'Usage chart');
  late int _selected = _clamp(
    widget.initialSelectedIndex ?? widget.days.length - 1,
  );
  bool _risen = false;
  bool _ring = false;
  double _slot = 0;
  double _view = 0;

  int _clamp(int index) =>
      widget.days.isEmpty ? 0 : index.clamp(0, widget.days.length - 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _rise.value = 1;
      _risen = true;
    } else if (!_risen) {
      _risen = true;
      _rise.forward();
    }
  }

  @override
  void didUpdateWidget(UsageChart old) {
    super.didUpdateWidget(old);
    if (old.metric != widget.metric || old.window != widget.window) {
      _selected = _clamp(widget.days.length - 1);
      if (!reduceMotionOf(context)) _rise.forward(from: 0);
    } else if (_selected >= widget.days.length) {
      _selected = _clamp(widget.days.length - 1);
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _select(int index, {bool reveal = false}) {
    final next = _clamp(index);
    if (widget.days.isEmpty) return;
    if (next != _selected) {
      setState(() => _selected = next);
      widget.onSelected?.call(next);
    }
    // Also for the bar that is already selected: it may have been scrolled
    // off screen since.
    if (reveal) _revealSelected();
  }

  void _selectAt(double dx) {
    if (_slot <= 0) return;
    _select((dx / _slot).floor());
  }

  /// The scroll view is reversed so it opens at the newest day, which makes
  /// its offset the distance from the right edge.
  void _revealSelected() {
    if (!_scroll.hasClients || !widget.window.scrolls) return;
    final content = _slot * widget.days.length;
    final left = _selected * _slot;
    final right = left + _slot;
    final viewLeft = content - _view - _scroll.offset;
    double? target;
    if (left < viewLeft) {
      target = content - _view - left;
    } else if (right > viewLeft + _view) {
      target = content - right;
    }
    if (target != null) {
      _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _select(_selected - 1, reveal: true);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _select(_selected + 1, reveal: true);
    } else if (key == LogicalKeyboardKey.home) {
      _select(0, reveal: true);
    } else if (key == LogicalKeyboardKey.end) {
      _select(widget.days.length - 1, reveal: true);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = context.hermesColors.subtleText;
    final scaler = MediaQuery.textScalerOf(context);
    final large = _isAccessibilityTextScale(scaler);
    final axisScaler = large
        ? TextScaler.noScaling
        : scaler.clamp(maxScaleFactor: 1.3);
    // The theme's own style, so the labels use its font like the rest.
    final axisStyle = Theme.of(context).textTheme.bodySmall!
        .copyWith(fontSize: 11, color: muted);
    final metric = widget.metric;
    final window = widget.window;

    final maxValue = days.fold<double>(0, (m, d) => math.max(m, d.value));
    final step = usageAxisStep(
      maxValue,
      fallback: metric == UsageChartMetric.tokens ? 400000 : 0.6,
    );
    final axisMax = step * 3;
    String yText(double v) => metric == UsageChartMetric.tokens
        ? formatCompact(l10n, v)
        : formatDollars(l10n, v);
    // A tiny maximum can round several gridlines to the same text; showing
    // a label twice says nothing, so a repeat is left blank.
    final yLabels = <String>[];
    for (var k = 1; k <= 3; k++) {
      final text = yText(step * k);
      yLabels.add(yLabels.contains(text) ? '' : text);
    }

    TextPainter measure(String text) => TextPainter(
      text: TextSpan(text: text, style: axisStyle),
      textDirection: TextDirection.ltr,
      textScaler: axisScaler,
    )..layout();
    final gutter =
        yLabels.map((t) => measure(t).width).reduce(math.max).ceilToDouble() +
        8;
    final labelHeight = measure('Nov').height;

    final selectedDay = days[_selected];
    final selectedText = [
      formatDayShort(l10n, selectedDay.day),
      _valueText(l10n, metric, selectedDay.value),
      formatConversations(l10n, selectedDay.conversations),
    ].join(' · ');
    final labels = [
      for (final d in days)
        l10n.serverCareUsageChartBar(
          formatDayLong(l10n, d.day),
          _valueSpoken(l10n, metric, d.value),
          formatConversations(l10n, d.conversations),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            widget.height ?? usageChartHeightFor(constraints.maxWidth);
        final available = math.max(0.0, constraints.maxWidth - gutter);
        final minSlot = window.scrolls ? _minBarTarget : 0.0;
        final slot = math.max(minSlot, available / days.length);
        _slot = slot;
        _view = available;
        final xLabelHeight = large ? 0.0 : labelHeight + 6;
        final topPad = (labelHeight / 2).ceilToDouble();
        final plotHeight = math.max(1.0, height - topPad - xLabelHeight);

        final xLabels = <int, String>{};
        if (!large) {
          for (var i = 0; i < days.length; i++) {
            final d = days[i].day;
            if (window == UsageChartWindow.days90) {
              if (d.day == 1) xLabels[i] = formatMonthShort(l10n, d);
            } else if (d.weekday == DateTime.monday) {
              xLabels[i] = formatDayShort(l10n, d);
            }
          }
        }

        final painter = UsageChartPlotPainter(
          rise: _rise,
          values: [for (final d in days) d.value],
          labels: labels,
          selected: _selected,
          slot: slot,
          axisMax: axisMax,
          topPad: topPad,
          plotHeight: plotHeight,
          xLabels: xLabels,
          xLabelStyle: axisStyle,
          xLabelScaler: axisScaler,
          barColor: muted,
          selectedColor: scheme.primary,
          gridColor: scheme.outlineVariant,
          baselineColor: scheme.outline,
          onPick: _select,
        );
        Widget plot = MouseRegion(
          onHover: (e) {
            if (e.kind == PointerDeviceKind.mouse) {
              _selectAt(e.localPosition.dx);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: (d) {
              _focus.requestFocus();
              _selectAt(d.localPosition.dx);
            },
            onHorizontalDragStart: window.scrolls
                ? null
                : (d) => _selectAt(d.localPosition.dx),
            onHorizontalDragUpdate: window.scrolls
                ? null
                : (d) => _selectAt(d.localPosition.dx),
            child: CustomPaint(
              size: Size(slot * days.length, height),
              painter: painter,
            ),
          ),
        );
        if (window.scrolls) {
          plot = Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: plot,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  selectedText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Focus(
              focusNode: _focus,
              onKeyEvent: _onKey,
              onFocusChange: (focused) => setState(
                () => _ring =
                    focused &&
                    FocusManager.instance.highlightMode ==
                        FocusHighlightMode.traditional,
              ),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: _summary(l10n, days, metric, window),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: _ring
                        ? Border.all(color: scheme.primary, width: 2)
                        : null,
                  ),
                  child: SizedBox(
                    height: height,
                    child: Row(
                      children: [
                        SizedBox(
                          width: gutter,
                          height: height,
                          child: CustomPaint(
                            painter: _AxisPainter(
                              labels: yLabels,
                              style: axisStyle,
                              scaler: axisScaler,
                              topPad: topPad,
                              plotHeight: plotHeight,
                            ),
                          ),
                        ),
                        Expanded(child: plot),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

TextPainter _text(String text, TextStyle style, TextScaler scaler) =>
    TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

class _AxisPainter extends CustomPainter {
  _AxisPainter({
    required this.labels,
    required this.style,
    required this.scaler,
    required this.topPad,
    required this.plotHeight,
  });

  final List<String> labels;
  final TextStyle style;
  final TextScaler scaler;
  final double topPad;
  final double plotHeight;

  @override
  void paint(Canvas canvas, Size size) {
    for (var k = 1; k <= labels.length; k++) {
      final tp = _text(labels[k - 1], style, scaler);
      final y = topPad + plotHeight * (1 - k / labels.length);
      tp.paint(canvas, Offset(size.width - 8 - tp.width, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      !listEquals(old.labels, labels) ||
      old.style != style ||
      old.topPad != topPad ||
      old.plotHeight != plotHeight;
}

/// Public only so a test can read what is drawn.
@visibleForTesting
class UsageChartPlotPainter extends CustomPainter {
  UsageChartPlotPainter({
    required this.rise,
    required this.values,
    required this.labels,
    required this.selected,
    required this.slot,
    required this.axisMax,
    required this.topPad,
    required this.plotHeight,
    required this.xLabels,
    required this.xLabelStyle,
    required this.xLabelScaler,
    required this.barColor,
    required this.selectedColor,
    required this.gridColor,
    required this.baselineColor,
    required this.onPick,
  }) : super(repaint: rise);

  final Animation<double> rise;
  final List<double> values;
  final List<String> labels;
  final int selected;
  final double slot;
  final double axisMax;
  final double topPad;
  final double plotHeight;
  final Map<int, String> xLabels;
  final TextStyle xLabelStyle;
  final TextScaler xLabelScaler;
  final Color barColor;
  final Color selectedColor;
  final Color gridColor;
  final Color baselineColor;
  final ValueChanged<int> onPick;

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = topPad + plotHeight;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var k = 1; k <= 3; k++) {
      final y = (bottom - plotHeight * k / 3).roundToDouble() + 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(
      Offset(0, bottom + 0.5),
      Offset(size.width, bottom + 0.5),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 1,
    );

    // The selected day's whole column is tinted, so it reads at a glance
    // even when its own bar is short or empty.
    if (selected >= 0 && selected < values.length) {
      canvas.drawRect(
        Rect.fromLTWH(selected * slot, topPad, slot, plotHeight),
        Paint()..color = selectedColor.withValues(alpha: 0.12),
      );
    }

    final barWidth = (slot * 0.62).clamp(2.0, 24.0).toDouble();
    final grow = Curves.easeOut.transform(rise.value);
    for (var i = 0; i < values.length; i++) {
      final x = i * slot + (slot - barWidth) / 2;
      final paint = Paint()..color = i == selected ? selectedColor : barColor;
      if (values[i] <= 0) {
        canvas.drawRect(Rect.fromLTWH(x, bottom - 1, barWidth, 1), paint);
        continue;
      }
      final h = math.max(2.0, values[i] / axisMax * plotHeight * grow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottom - h, barWidth, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    for (final MapEntry(key: i, value: text) in xLabels.entries) {
      final tp = _text(text, xLabelStyle, xLabelScaler);
      final x = (i * slot + slot / 2 - tp.width / 2)
          .clamp(0.0, math.max(0.0, size.width - tp.width))
          .toDouble();
      tp.paint(canvas, Offset(x, bottom + 4));
    }
  }

  @override
  bool shouldRepaint(UsageChartPlotPainter old) =>
      !listEquals(old.values, values) ||
      old.selected != selected ||
      old.slot != slot ||
      old.axisMax != axisMax ||
      old.topPad != topPad ||
      old.plotHeight != plotHeight ||
      !mapEquals(old.xLabels, xLabels) ||
      old.xLabelStyle != xLabelStyle ||
      old.xLabelScaler != xLabelScaler ||
      old.barColor != barColor ||
      old.selectedColor != selectedColor ||
      old.gridColor != gridColor ||
      old.baselineColor != baselineColor;

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (var i = 0; i < labels.length; i++)
          CustomPainterSemantics(
            key: ValueKey(i),
            rect: Rect.fromLTWH(i * slot, 0, slot, size.height),
            properties: SemanticsProperties(
              label: labels[i],
              selected: i == selected,
              textDirection: TextDirection.ltr,
              onTap: () => onPick(i),
            ),
          ),
      ];

  @override
  bool shouldRebuildSemantics(UsageChartPlotPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.slot != slot ||
      !listEquals(oldDelegate.labels, labels);
}

/// A grey stand-in for the chart while usage loads: thirty bars. Decorative;
/// the page labels the loading state once, with a [LoadingSkeleton].
class UsageChartSkeleton extends StatefulWidget {
  const UsageChartSkeleton({super.key, this.bars = 30});

  final int bars;

  @override
  State<UsageChartSkeleton> createState() => _UsageChartSkeletonState();
}

class _UsageChartSkeletonState extends State<UsageChartSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = usageChartHeightFor(constraints.maxWidth);
          return AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Opacity(
              opacity: 1 - 0.4 * _pulse.value,
              child: SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < widget.bars; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: FractionallySizedBox(
                            heightFactor: 0.2 + 0.6 * ((i * 7 + 3) % 11) / 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
