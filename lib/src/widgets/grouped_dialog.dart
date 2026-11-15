import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../l10n/l10n.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'grouped_list.dart';

/// A grouped settings or form dialog using the platform's page chrome.
/// Custom [actions] replace the default Done button.
class GroupedDialog extends StatelessWidget {
  const GroupedDialog({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });

  final String title;

  /// The [GroupedSection]s, and any [GroupedDialogNote] between them.
  final List<Widget> children;

  /// Null keeps Done in the header; custom actions appear in the footer.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final metrics = GroupedMetrics.of(context);
    final theme = Theme.of(context);
    final (maxWidth, radius) = switch (chrome) {
      PlatformChrome.ios => (400.0, 14.0),
      PlatformChrome.macos => (460.0, 10.0),
      PlatformChrome.material => (560.0, 28.0),
    };
    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      // A phone gives the rows, and a warning beside a switch, the width.
      insetPadding: chrome == PlatformChrome.macos
          ? null
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: hermesOverlayEdge(theme.colorScheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          // The room the dialog really gets (Dialog has already taken the
          // keyboard and the insets off it) decides how tall the header may be.
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Title(
                  title: title,
                  chrome: chrome,
                  showDone: actions == null,
                  room: constraints.maxHeight,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      metrics.gutter,
                      0,
                      metrics.gutter,
                      metrics.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                if (actions != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(metrics.gutter),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: actions!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A muted paragraph between or after the groups of a [GroupedDialog], set
/// like a [GroupedSection]'s footer.
class GroupedDialogNote extends StatelessWidget {
  const GroupedDialogNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        metrics.sectionGap / 2,
        metrics.rowPadding,
        0,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: metrics.footerSize,
          color: context.hermesColors.subtleText,
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({
    required this.title,
    required this.chrome,
    required this.showDone,
    required this.room,
  });

  final String title;
  final PlatformChrome chrome;
  final bool showDone;

  /// The height the dialog may take, with the keyboard already off it.
  final double room;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (chrome == PlatformChrome.material) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
        ),
      );
    }
    final ios = chrome == PlatformChrome.ios;
    final fontSize = ios ? 17.0 : 13.0;
    // A long title (it can come from user data) grows the header, but never
    // past a share of the dialog's room: beyond that the title scrolls, so
    // the rows below keep theirs and Done stays in view.
    final minHeight = ios ? kAppleNavBarHeight + 8 : 44.0;
    return _TitleBar(
      // Tight room (a landscape keyboard) keeps the resting height: the title
      // scrolls in a one-line bar rather than taking room from the rows.
      maxHeight: !room.isFinite
          ? 1e9
          : (0.4 * room < 1.5 * minHeight ? minHeight : 0.4 * room),
      minHeight: minHeight,
      doneInset: ios ? 4 : 8,
      textDirection: Directionality.of(context),
      // Screen readers follow the sort keys, not the position: stacked, Done
      // sits above the title but is still read after it.
      title: Semantics(
        sortKey: const OrdinalSortKey(0),
        child: _ScrollingTitle(
          title: title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: ios ? FontWeight.w600 : FontWeight.w700,
            color: onSurface,
          ),
        ),
      ),
      done: showDone
          ? Semantics(
              sortKey: const OrdinalSortKey(1),
              child: TextButton(
                key: const Key('grouped-dialog-done'),
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  minimumSize: Size(
                    ios ? kAppleMinTapTarget : 0,
                    ios ? 44 : 28,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.widgetsDone),
              ),
            )
          : null,
    );
  }
}

/// The title of the header: it scrolls when the header's cap clips it, and a
/// fade at the bottom edge says there is more.
class _ScrollingTitle extends StatefulWidget {
  const _ScrollingTitle({required this.title, required this.style});

  final String title;
  final TextStyle style;

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle> {
  static const _fade = 20.0;

  bool _more = false;

  bool _update(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 0.5;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _update(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _update(n.metrics),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0, _more ? math.max(0, 1 - _fade / rect.height) : 1, 1],
            ).createShader(rect),
            child: SingleChildScrollView(
              primary: false,
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: widget.style,
                ),
              ),
            ),
          ),
        ),
      );
}

/// The header of an Apple or desktop [GroupedDialog]: the title centred, the
/// Done button at the end. It grows with the text instead of keeping a fixed
/// height, hands the title what Done leaves, and when the title does not fit
/// on one line beside Done, gives Done its own row with the title under it.
class _TitleBar extends MultiChildRenderObjectWidget {
  _TitleBar({
    required this.maxHeight,
    required this.minHeight,
    required this.doneInset,
    required this.textDirection,
    required Widget title,
    Widget? done,
  }) : super(children: [title, ?done]);

  final double maxHeight;
  final double minHeight;
  final double doneInset;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTitleBar(
    maxHeight: maxHeight,
    minHeight: minHeight,
    doneInset: doneInset,
    textDirection: textDirection,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderTitleBar renderObject) {
    renderObject
      ..maxHeight = maxHeight
      ..minHeight = minHeight
      ..doneInset = doneInset
      ..textDirection = textDirection;
  }
}

class _TitleBarParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTitleBar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TitleBarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TitleBarParentData> {
  _RenderTitleBar({
    required this._maxHeight,
    required this._minHeight,
    required this._doneInset,
    required this._textDirection,
  });

  static const _sidePadding = 16.0;
  static const _gap = 8.0;
  static const _verticalPadding = 8.0;

  double _maxHeight;
  set maxHeight(double value) {
    if (_maxHeight == value) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  double _minHeight;
  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  double _doneInset;
  set doneInset(double value) {
    if (_doneInset == value) return;
    _doneInset = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TitleBarParentData) {
      child.parentData = _TitleBarParentData();
    }
  }

  RenderBox get _title => firstChild!;
  RenderBox? get _done => childAfter(_title);

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(
    BoxConstraints(maxWidth: width.isFinite ? width : _maxWidth(null)),
  ).height;

  @override
  double computeMinIntrinsicWidth(double height) {
    final done = _done;
    final doneWidth = done == null ? 0.0 : done.getMinIntrinsicWidth(height);
    return math.max(
      _title.getMinIntrinsicWidth(height) + 2 * _sidePadding,
      doneWidth + 2 * _doneInset,
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) => _maxWidth(height);

  double _maxWidth(double? height) {
    final h = height ?? double.infinity;
    final done = _done;
    final doneWidth = done == null ? 0.0 : done.getMaxIntrinsicWidth(h);
    final doneSpan = done == null ? 0.0 : doneWidth + _doneInset + _gap;
    return _title.getMaxIntrinsicWidth(h) + _sidePadding + doneSpan;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, (child, c) => child.getDryLayout(c), null);

  @override
  void performLayout() {
    size = _layout(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    }, _place);
  }

  /// Offsets are computed from the start side and mirrored for right to left
  /// text when they are placed.
  void _place(RenderBox child, double x, double y, double width, double bar) {
    final dx = _textDirection == TextDirection.ltr ? x : bar - x - width;
    (child.parentData! as _TitleBarParentData).offset = Offset(dx, y);
  }

  Size _layout(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
    void Function(RenderBox, double, double, double, double)? place,
  ) {
    final width = constraints.maxWidth;
    final done = _done;
    final doneSize = done == null
        ? Size.zero
        : layoutChild(done, BoxConstraints(maxWidth: width));
    final doneSpan = done == null ? 0.0 : doneSize.width + _doneInset + _gap;
    final beside = width - doneSpan - _sidePadding;
    final stacked =
        done != null && _title.getMaxIntrinsicWidth(double.infinity) > beside;

    final titleMax = stacked ? width - 2 * _sidePadding : beside;
    // The title scrolls once the header would pass its share of the screen.
    final doneRow = math.max(doneSize.height, kAppleMinTapTarget);
    final titleRoom = stacked
        ? math.max(_maxHeight - doneRow - _verticalPadding, 24.0)
        : math.max(
            _maxHeight - 2 * _verticalPadding,
            _minHeight - 2 * _verticalPadding,
          );
    final titleSize = layoutChild(
      _title,
      BoxConstraints(maxWidth: math.max(0, titleMax), maxHeight: titleRoom),
    );

    final double height;
    if (stacked) {
      // Done keeps its own row of at least a tap target, the title wraps
      // under it.
      height = math.max(
        _minHeight,
        doneRow + titleSize.height + _verticalPadding,
      );
      if (place != null) {
        place(
          done,
          width - doneSize.width - _doneInset,
          (doneRow - doneSize.height) / 2,
          doneSize.width,
          width,
        );
        place(
          _title,
          (width - titleSize.width) / 2,
          doneRow,
          titleSize.width,
          width,
        );
      }
    } else {
      height = math.max(
        _minHeight,
        math.max(titleSize.height + 2 * _verticalPadding, doneSize.height),
      );
      if (place != null) {
        final limit = width - doneSpan;
        final x = math.max(
          _sidePadding,
          math.min((width - titleSize.width) / 2, limit - titleSize.width),
        );
        place(
          _title,
          x,
          (height - titleSize.height) / 2,
          titleSize.width,
          width,
        );
        if (done != null) {
          place(
            done,
            width - doneSize.width - _doneInset,
            (height - doneSize.height) / 2,
            doneSize.width,
            width,
          );
        }
      }
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
