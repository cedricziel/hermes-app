import 'package:flutter/material.dart';

/// An [ExpansionTile] whose header screen readers announce as a button that
/// is open or closed.
///
/// The tile alone only gives a hint, which the macOS accessibility bridge
/// drops, so VoiceOver there would read the header as plain text.
class DisclosureTile extends StatefulWidget {
  const DisclosureTile({
    super.key,
    required this.title,
    required this.children,
    this.enabled = true,
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.dense,
    this.shape,
    this.collapsedShape,
    this.tilePadding,
    this.childrenPadding,
    this.expandedCrossAxisAlignment,
    this.minTileHeight,
    this.iconColor,
    this.collapsedIconColor,
    this.trailing,
  });

  final Widget title;
  final List<Widget> children;
  final bool enabled;
  final bool initiallyExpanded;
  final bool maintainState;
  final bool? dense;
  final ShapeBorder? shape;
  final ShapeBorder? collapsedShape;
  final EdgeInsetsGeometry? tilePadding;
  final EdgeInsetsGeometry? childrenPadding;
  final CrossAxisAlignment? expandedCrossAxisAlignment;
  final double? minTileHeight;
  final Color? iconColor;
  final Color? collapsedIconColor;
  final Widget? trailing;

  @override
  State<DisclosureTile> createState() => _DisclosureTileState();
}

class _DisclosureTileState extends State<DisclosureTile> {
  // The tile's own state, which page storage may restore while it builds.
  final _controller = ExpansibleController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    controller: _controller,
    enabled: widget.enabled,
    initiallyExpanded: widget.initiallyExpanded,
    maintainState: widget.maintainState,
    dense: widget.dense,
    shape: widget.shape,
    collapsedShape: widget.collapsedShape,
    tilePadding: widget.tilePadding,
    childrenPadding: widget.childrenPadding,
    expandedCrossAxisAlignment: widget.expandedCrossAxisAlignment,
    minTileHeight: widget.minTileHeight,
    iconColor: widget.iconColor,
    collapsedIconColor: widget.collapsedIconColor,
    trailing: widget.trailing,
    title: widget.enabled
        ? ListenableBuilder(
            listenable: _controller,
            builder: (context, title) => Semantics(
              button: true,
              expanded: _controller.isExpanded,
              child: title,
            ),
            child: widget.title,
          )
        : widget.title,
    children: widget.children,
  );
}
