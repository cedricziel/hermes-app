import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';

/// A list that looks like one [GroupedSection] (a card with a hairline border,
/// rounded corners and separators inset to the text) but builds only the rows
/// on screen, so a folder of thousands of files costs a screenful.
///
/// Each row draws its slice of the card: the first the top corners, the last
/// the bottom ones, the others only the sides, plus a separator above every
/// row but the first. [leading] (notes and banners) and the optional [footer]
/// sit outside the card.
class FilesLazyList extends StatelessWidget {
  const FilesLazyList({
    super.key,
    this.leading = const [],
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
    this.dividerIndent,
  });

  final List<Widget> leading;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// A note under the card, such as how many rows were left out.
  final String? footer;

  /// Where the separators start; the row padding when null.
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final footer = this.footer;
    final total = leading.length + itemCount + (footer == null ? 0 : 1);
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          metrics.gutter,
          (box.maxWidth - metrics.maxWidth) / 2,
        );
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(side, 0, side, 32),
          itemCount: total,
          itemBuilder: (context, index) {
            if (index < leading.length) return leading[index];
            final row = index - leading.length;
            if (row < itemCount) {
              return Padding(
                padding: EdgeInsets.only(top: row == 0 ? 8 : 0),
                child: CardSlice(
                  first: row == 0,
                  last: row == itemCount - 1,
                  radius: metrics.radius,
                  dividerIndent: dividerIndent ?? metrics.rowPadding,
                  child: itemBuilder(context, row),
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.rowPadding,
                6,
                metrics.rowPadding,
                0,
              ),
              child: Text(
                footer!,
                style: TextStyle(fontSize: metrics.footerSize, color: muted),
              ),
            );
          },
        );
      },
    );
  }
}

/// One row of a card that is drawn row by row: the card's fill, hairline and
/// corners for this row's part of it, and a separator above all but the first.
class CardSlice extends StatelessWidget {
  const CardSlice({
    super.key,
    required this.first,
    required this.last,
    required this.radius,
    required this.dividerIndent,
    required this.child,
  });

  final bool first;
  final bool last;
  final double radius;
  final double dividerIndent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final corners = BorderRadius.vertical(
      top: Radius.circular(first ? radius : 0),
      bottom: Radius.circular(last ? radius : 0),
    );
    return CustomPaint(
      painter: _CardSlicePainter(
        fill: scheme.surface,
        line: scheme.outline,
        radius: radius,
        first: first,
        last: last,
      ),
      child: ClipRRect(
        borderRadius: corners,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!first)
              Divider(
                height: 1,
                indent: dividerIndent,
                color: scheme.outlineVariant,
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Paints the card's rounded rectangle, taller than the slice at the ends that
/// are not the card's, and clipped to the slice: only the part that belongs to
/// this row shows.
class _CardSlicePainter extends CustomPainter {
  const _CardSlicePainter({
    required this.fill,
    required this.line,
    required this.radius,
    required this.first,
    required this.last,
  });

  final Color fill;
  final Color line;
  final double radius;
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final extend = radius * 2 + 2;
    final top = first ? 0.0 : -extend;
    final bottom = size.height + (last ? 0.0 : extend);
    final rect = Rect.fromLTRB(0, top, size.width, bottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius - 0.5)),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CardSlicePainter old) =>
      old.fill != fill ||
      old.line != line ||
      old.radius != radius ||
      old.first != first ||
      old.last != last;
}
