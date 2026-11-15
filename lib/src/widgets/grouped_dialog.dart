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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Title(title: title, chrome: chrome, showDone: actions == null),
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
    return _TitleBar(
      minHeight: ios ? kAppleNavBarHeight + 8 : 44,
      doneInset: ios ? 4 : 8,
      textDirection: Directionality.of(context),
      title: Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: ios ? FontWeight.w600 : FontWeight.w700,
            color: onSurface,
          ),
        ),
      ),
      done: showDone
          ? TextButton(
              key: const Key('grouped-dialog-done'),
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600),
                minimumSize: Size(ios ? kAppleMinTapTarget : 0, ios ? 44 : 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.widgetsDone),
            )
          : null,
    );
  }
}

/// The header of an Apple or desktop [GroupedDialog]: the title centred, the
/// Done button at the end. It grows with the text instead of keeping a fixed
/// height, hands the title what Done leaves, and moves the title under Done
/// when even its longest word would not fit beside it.
class _TitleBar extends MultiChildRenderObjectWidget {
  _TitleBar({
    required this.minHeight,
    required this.doneInset,
    required this.textDirection,
    required Widget title,
    Widget? done,
  }) : super(children: [title, ?done]);

  final double minHeight;
  final double doneInset;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTitleBar(
    minHeight: minHeight,
    doneInset: doneInset,
    textDirection: textDirection,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderTitleBar renderObject) {
    renderObject
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
    required this._minHeight,
    required this._doneInset,
    required this._textDirection,
  });

  static const _sidePadding = 16.0;
  static const _gap = 8.0;
  static const _verticalPadding = 8.0;

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
  double computeMinIntrinsicHeight(double width) => _minHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _minHeight;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

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
        done != null && _title.getMinIntrinsicWidth(double.infinity) > beside;

    final titleMax = stacked ? width - 2 * _sidePadding : beside;
    final titleSize = layoutChild(
      _title,
      BoxConstraints(maxWidth: math.max(0, titleMax)),
    );

    final double height;
    if (stacked) {
      // Done keeps its own row of at least a tap target, the title wraps
      // under it.
      final doneRow = math.max(doneSize.height, kAppleMinTapTarget);
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
