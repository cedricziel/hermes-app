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
          // The header, the rows and the footer share the room the dialog
          // really gets: the footer is measured first and the header is
          // capped so it never takes room the footer needs.
          child: _DialogColumn(
            children: [
              _Title(title: title, chrome: chrome, showDone: actions == null),
              SingleChildScrollView(
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
              if (actions != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                ),
            ],
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
  });

  final String title;
  final PlatformChrome chrome;
  final bool showDone;

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
    final minHeight = ios ? kAppleNavBarHeight + 8 : 44.0;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: ios ? FontWeight.w600 : FontWeight.w700,
      color: onSurface,
    );
    // Measured with the style the Text will really have (the dialog's
    // DefaultTextStyle supplies the theme's line height, family and spacing),
    // the text scale and the locale, so the header reserves what is drawn.
    final measured = DefaultTextStyle.of(context).style.merge(style);
    final heightBehavior = DefaultTextStyle.of(context).textHeightBehavior;
    final locale = Localizations.maybeLocaleOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text, {required bool width}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: measured),
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
        textHeightBehavior: heightBehavior,
      )..layout();
      final size = width ? painter.width : painter.height;
      painter.dispose();
      return size;
    }

    final lineHeight = measure('Ag', width: false);
    final titleWidth = measure(title, width: true);
    return _TitleBar(
      minHeight: minHeight,
      lineHeight: lineHeight,
      titleWidth: titleWidth,
      doneInset: ios ? 4 : 8,
      textDirection: Directionality.of(context),
      // Screen readers follow the sort keys, not the position: stacked, Done
      // sits above the title but is still read after it.
      title: Semantics(
        sortKey: const OrdinalSortKey(0),
        child: _ScrollingTitle(
          title: title,
          style: style,
          lineHeight: lineHeight,
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
  const _ScrollingTitle({
    required this.title,
    required this.style,
    required this.lineHeight,
  });

  final String title;
  final TextStyle style;
  final double lineHeight;

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle> {
  bool _more = false;

  bool _update(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 0.5;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The header lays the title out with a tight height when the rows need
      // the room (the header's one-line form): the title is then cut with an
      // ellipsis, the long-press tooltip and the semantics label carry it in
      // full. Otherwise it wraps and, past the header's cap, scrolls.
      if (constraints.hasTightHeight) {
        return ClipRect(
          child: Center(
            child: Tooltip(
              message: widget.title,
              excludeFromSemantics: true,
              child: Semantics(
                header: true,
                label: widget.title,
                excludeSemantics: true,
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: widget.style,
                ),
              ),
            ),
          ),
        );
      }
      // The fade is shorter than a line, so a visible line never sits under it.
      final fade = math.min(20.0, 0.4 * widget.lineHeight);
      return NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _update(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _update(n.metrics),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0, _more ? math.max(0, 1 - fade / rect.height) : 1, 1],
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
    },
  );
}

/// The header of an Apple or desktop [GroupedDialog]: the title centred, the
/// Done button at the end. It grows with the text instead of keeping a fixed
/// height, hands the title what Done leaves, and when the title does not fit
/// on one line beside Done, gives Done its own row with the title under it.
class _TitleBar extends MultiChildRenderObjectWidget {
  _TitleBar({
    required this.minHeight,
    required this.lineHeight,
    required this.titleWidth,
    required this.doneInset,
    required this.textDirection,
    required Widget title,
    Widget? done,
  }) : super(children: [title, ?done]);

  final double minHeight;
  final double lineHeight;
  final double titleWidth;
  final double doneInset;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTitleBar(
    minHeight: minHeight,
    lineHeight: lineHeight,
    titleWidth: titleWidth,
    doneInset: doneInset,
    textDirection: textDirection,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderTitleBar renderObject) {
    renderObject
      ..minHeight = minHeight
      ..lineHeight = lineHeight
      ..titleWidth = titleWidth
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
    required this._minHeight,
    required this._lineHeight,
    required this._titleWidth,
    required this._doneInset,
    required this._textDirection,
  });

  static const _sidePadding = 16.0;
  static const _gap = 8.0;
  static const _verticalPadding = 8.0;

  double _titleWidth;
  set titleWidth(double value) {
    if (_titleWidth == value) return;
    _titleWidth = value;
    markNeedsLayout();
  }

  double _lineHeight;
  set lineHeight(double value) {
    if (_lineHeight == value) return;
    _lineHeight = value;
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
    return math.max(2 * _sidePadding, doneWidth + 2 * _doneInset);
  }

  @override
  double computeMaxIntrinsicWidth(double height) => _maxWidth(height);

  double _maxWidth(double? height) {
    final h = height ?? double.infinity;
    final done = _done;
    final doneWidth = done == null ? 0.0 : done.getMaxIntrinsicWidth(h);
    final doneSpan = done == null ? 0.0 : doneWidth + _doneInset + _gap;
    return _titleWidth + _sidePadding + doneSpan;
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

  /// The header's one-line form: the resting height, or Done's own height
  /// when that is taller, so Done is always whole. The title is cut with an
  /// ellipsis in it. Handed down as the maximum height, it asks for that form.
  double oneLineHeight(double width) {
    final done = _done;
    if (done == null) return _minHeight;
    return math.max(
      _minHeight,
      done.getDryLayout(BoxConstraints(maxWidth: width)).height,
    );
  }

  /// The least height the grown form needs to hold one whole line of the
  /// title (and Done's row above it when the title is stacked). Below it the
  /// parent asks for the one-line form instead.
  double minGrownHeight(double width) {
    final done = _done;
    final oneLine = math.max(_minHeight, _lineHeight + 2 * _verticalPadding);
    if (done == null) return oneLine;
    final doneSize = done.getDryLayout(BoxConstraints(maxWidth: width));
    final beside = width - (doneSize.width + _doneInset + _gap) - _sidePadding;
    if (_titleWidth <= beside) return oneLine;
    return math.max(doneSize.height, kAppleMinTapTarget) +
        _lineHeight +
        _verticalPadding;
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
    // Without Done the title keeps the same padding on both sides.
    final reserve = done == null ? _sidePadding : doneSpan;
    final beside = width - reserve - _sidePadding;
    final oneLine =
        constraints.hasBoundedHeight &&
        constraints.maxHeight <= math.max(_minHeight, doneSize.height) + 0.01;
    final stacked = !oneLine && done != null && _titleWidth > beside;

    final titleMax = stacked ? width - 2 * _sidePadding : beside;
    // The parent caps the header (and gives it at least minGrownHeight, or
    // asks for the one-line form); the title scrolls once it would pass it.
    final cap = constraints.maxHeight;
    final doneRow = math.max(doneSize.height, kAppleMinTapTarget);
    final titleRoom = math.max(
      0.0,
      stacked ? cap - doneRow - _verticalPadding : cap - 2 * _verticalPadding,
    );
    final bar = math.max(_minHeight, doneSize.height);
    final titleSize = layoutChild(
      _title,
      oneLine
          ? BoxConstraints(
              maxWidth: math.max(0, titleMax),
              minHeight: bar,
              maxHeight: bar,
            )
          : BoxConstraints(
              maxWidth: math.max(0, titleMax),
              maxHeight: titleRoom,
            ),
    );

    final double height;
    if (oneLine) {
      height = bar;
      if (place != null) {
        final limit = width - reserve;
        final x = math.max(
          _sidePadding,
          math.min((width - titleSize.width) / 2, limit - titleSize.width),
        );
        place(_title, x, 0, titleSize.width, width);
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
    } else if (stacked) {
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
        math.max(
          math.min(titleSize.height + 2 * _verticalPadding, cap),
          doneSize.height,
        ),
      );
      if (place != null) {
        final limit = width - reserve;
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
  void paint(PaintingContext context, Offset offset) => context.pushClipRect(
    needsCompositing,
    offset,
    Offset.zero & size,
    defaultPaint,
  );

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _DialogColumnParentData extends ContainerBoxParentData<RenderBox> {}

/// Header, rows and an optional footer, one under the other. The footer is
/// laid out first and the header is capped at 40% of the room, but never so
/// that it takes room the footer needs; in tight room it falls back to the
/// least height that still shows one whole line of the title.
class _DialogColumn extends MultiChildRenderObjectWidget {
  const _DialogColumn({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDialogColumn();
}

class _RenderDialogColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DialogColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DialogColumnParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DialogColumnParentData) {
      child.parentData = _DialogColumnParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, (child, c) => child.getDryLayout(c), null);

  @override
  void performLayout() {
    size = _layout(
      constraints,
      (child, c) {
        child.layout(c, parentUsesSize: true);
        return child.size;
      },
      (child, y) =>
          (child.parentData! as _DialogColumnParentData).offset = Offset(0, y),
    );
  }

  Size _layout(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) layoutChild,
    void Function(RenderBox, double)? place,
  ) {
    final width = constraints.maxWidth;
    final room = constraints.maxHeight;
    final header = firstChild!;
    final body = childAfter(header)!;
    final footer = childAfter(body);

    final tight = BoxConstraints(minWidth: width, maxWidth: width);
    final footerHeight = footer == null
        ? 0.0
        : layoutChild(footer, tight).height;

    // Rows win: the header may grow past its one-line form (up to 40% of
    // the room) only while the rows keep the height they would have under
    // the one-line header. Otherwise the title is cut to one line.
    var headerLimit = double.infinity;
    if (header is _RenderTitleBar && room.isFinite) {
      final oneLine = header.oneLineHeight(width);
      final available = math.max(0.0, room - footerHeight);
      // The rows' natural height from intrinsics, not from a layout of the
      // scroll view, which would reset its scroll position. A body that
      // cannot answer is taken to need all the room.
      double natural;
      try {
        natural = body.getMaxIntrinsicHeight(width);
      } on Object {
        natural = double.infinity;
      }
      final mostForHeader = math.max(oneLine, available - natural);
      final cap = math.min(0.4 * room, mostForHeader);
      headerLimit = cap < math.max(1.5 * oneLine, header.minGrownHeight(width))
          ? oneLine
          : cap;
    }
    final headerHeight = layoutChild(
      header,
      tight.copyWith(maxHeight: headerLimit),
    ).height;
    final bodyHeight = layoutChild(
      body,
      tight.copyWith(
        maxHeight: room.isFinite
            ? math.max(0.0, room - headerHeight - footerHeight)
            : double.infinity,
      ),
    ).height;
    if (place != null) {
      place(header, 0);
      place(body, headerHeight);
      if (footer != null) place(footer, headerHeight + bodyHeight);
    }
    return constraints.constrain(
      Size(width, headerHeight + bodyHeight + footerHeight),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
