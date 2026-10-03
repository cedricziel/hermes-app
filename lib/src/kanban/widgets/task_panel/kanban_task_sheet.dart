import 'package:flutter/material.dart';

/// Room a sheet's grabber takes above its content.
const double kKanbanGrabberBand = 17;

const double _kSheetRadius = 12;
const double _kFormSheetWidth = 560;
const double _kFormSheetHeight = 720;

/// An iOS-style sheet: opens half way, drags up to full height, and a swipe
/// down past the medium detent dismisses it. [builder] gets the controller
/// the content's scroll view must use for the drag to work.
Future<void> showKanbanDetentSheet(
  BuildContext context,
  Widget Function(ScrollController controller) builder,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.5,
    minChildSize: 0,
    snap: true,
    snapSizes: const [0.5, 1],
    builder: (context, controller) => Material(
      key: const Key('kanbanTaskSheet'),
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_kSheetRadius),
        ),
      ),
      child: Stack(
        children: [
          builder(controller),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(child: _Grabber()),
          ),
        ],
      ),
    ),
  ),
);

/// A centred sheet with the iOS corner radius, for iPad and desktop widths.
Future<void> showKanbanFormSheet(BuildContext context, Widget panel) =>
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_kSheetRadius)),
        ),
        child: ConstrainedBox(
          key: const Key('kanbanTaskSheet'),
          constraints: const BoxConstraints(
            minWidth: _kFormSheetWidth,
            maxWidth: _kFormSheetWidth,
            maxHeight: _kFormSheetHeight,
          ),
          child: Padding(padding: const EdgeInsets.only(top: 12), child: panel),
        ),
      ),
    );

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: kKanbanGrabberBand,
      color: scheme.surface,
      alignment: Alignment.center,
      child: Container(
        key: const Key('kanbanTaskGrabber'),
        width: 36,
        height: 5,
        decoration: BoxDecoration(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }
}
