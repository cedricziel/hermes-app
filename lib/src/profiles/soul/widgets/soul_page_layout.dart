import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/grouped_list.dart';

/// The Personality page's frame: an optional [banner] on top, the [editor]
/// filling every bit of height that is left, and the [below] children under
/// it (status line, footnote).
///
/// The editor is a [SoulEditor] with `expands: true`. When the space is
/// short (a keyboard, the largest text, a banner) the page scrolls instead of
/// squeezing the editor below its own minimum, so nothing overflows. The
/// column is as wide as a grouped list's and centred, so a desktop window
/// keeps its 600 pt column.
///
/// It takes plain widgets, no controller.
class SoulPageLayout extends StatelessWidget {
  const SoulPageLayout({
    super.key,
    this.banner,
    required this.editor,
    this.below = const [],
  });

  /// A banner above the editor, already padded; it scrolls with the page.
  final Widget? banner;

  /// The editor, built with `expands: true`.
  final Widget editor;

  /// What follows the editor, top to bottom.
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          metrics.gutter,
          (box.maxWidth - metrics.maxWidth) / 2,
        );
        return CustomScrollView(
          slivers: [
            // Always one sliver, empty without a banner: the editor sliver
            // after it keeps its place, so a banner coming or going does not
            // rebuild the text field (focus, undo history).
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: SliverToBoxAdapter(
                child: banner ?? const SizedBox.shrink(),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 8, side, 0),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  minimum: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: editor),
                      ...below,
                    ],
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
