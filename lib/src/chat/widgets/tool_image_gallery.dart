import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import 'tool_image_tile.dart';

/// The widest a single image's tile is drawn.
const _singleWidth = 360.0;

/// How many tiles show before "Show all".
const kGalleryFirstTiles = 6;

/// Tiles in a grid: two columns on a phone, three from 560 pt and four from
/// 760 pt; a [single] image is one tile, at most 360 pt wide. Above them a
/// header counts the images (and the small ones left out) and offers Load
/// all; under them, Show all opens the rest in place. A plain model: the
/// tiles are built, and their loading owned, by the caller.
class ToolImageGallery extends StatefulWidget {
  const ToolImageGallery({
    super.key,
    required this.tiles,
    this.hidden = 0,
    this.single = false,
    this.onLoadAll,
  });

  final List<ToolImageTile> tiles;

  /// How many images under 32 px were left out.
  final int hidden;

  /// One image of a call (`image_generate`, `browser_vision`): no header.
  final bool single;

  /// Loads the tiles that show, given how many show. Offered only while a
  /// shown tile is waiting for a tap.
  final ValueChanged<int>? onLoadAll;

  @override
  State<ToolImageGallery> createState() => _ToolImageGalleryState();
}

class _ToolImageGalleryState extends State<ToolImageGallery> {
  var _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tiles = widget.tiles;
    final shown = _all ? tiles : tiles.take(kGalleryFirstTiles).toList();
    final subtle = context.hermesColors.subtleText;
    final buttonHeight = minTapTargetOf(context);
    if (tiles.isEmpty) {
      return Text(
        // Images all too small to show are still counted.
        widget.hidden > 0
            ? l10n.chatWidgetsImageHidden(widget.hidden)
            : l10n.chatWidgetsImageNone,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: subtle),
      );
    }
    if (widget.single) {
      return Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _singleWidth),
          child: tiles.first,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                [
                  l10n.chatWidgetsImageCount(tiles.length),
                  if (widget.hidden > 0)
                    l10n.chatWidgetsImageHidden(widget.hidden),
                ].join(' · '),
                style: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: subtle),
              ),
            ),
            if (widget.onLoadAll != null &&
                shown.any((t) => t.state == ToolImageState.idle))
              TextButton(
                style: TextButton.styleFrom(minimumSize: Size(0, buttonHeight)),
                onPressed: () => widget.onLoadAll!(shown.length),
                child: Text(l10n.chatWidgetsImageLoadAll),
              ),
          ],
        ),
        LayoutBuilder(
          builder: (context, box) {
            // One image is a large tile, however wide the page.
            if (tiles.length == 1) {
              return Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _singleWidth),
                  child: tiles.first,
                ),
              );
            }
            // Words at the largest text sizes need a tile's whole width.
            final columns = MediaQuery.textScalerOf(context).scale(1) > 1.6
                ? 1
                : box.maxWidth >= 760
                ? 4
                : box.maxWidth >= 560
                ? 3
                : 2;
            const gap = 8.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (final tile in shown) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        if (!_all && tiles.length > kGalleryFirstTiles)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: Size(0, buttonHeight)),
              onPressed: () => setState(() => _all = true),
              child: Text(l10n.chatWidgetsImageShowAll(tiles.length)),
            ),
          ),
      ],
    );
  }
}
