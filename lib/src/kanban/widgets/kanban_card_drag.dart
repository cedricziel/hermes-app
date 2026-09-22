import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/hermes_theme.dart';
import '../kanban_models.dart';
import 'kanban_card.dart';

/// What follows the pointer while [task] is dragged.
class KanbanDragFeedback extends StatelessWidget {
  const KanbanDragFeedback({super.key, required this.task});

  final KanbanTask task;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(kHermesRadius),
      child: KanbanCard(task: task),
    ),
  );
}

/// A card in a column that can be dragged to another. A mouse or trackpad
/// drags at once; a finger has to hold first, or it could not scroll the
/// column. Which one applies follows the pointer in use, not the platform: a
/// tablet takes both.
class KanbanDraggableCard extends StatelessWidget {
  const KanbanDraggableCard({
    super.key,
    required this.task,
    required this.child,
  });

  final KanbanTask task;

  /// The card as shown at rest.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final childWhenDragging = Opacity(
      opacity: 0.4,
      child: KanbanCard(task: task),
    );
    return _PointerDraggable(
      data: task,
      feedback: KanbanDragFeedback(task: task),
      childWhenDragging: childWhenDragging,
      child: _TouchDraggable(
        data: task,
        feedback: KanbanDragFeedback(task: task),
        childWhenDragging: childWhenDragging,
        child: child,
      ),
    );
  }
}

/// On a phone a long press selects, so the card is dragged by this handle.
class KanbanDragHandle extends StatelessWidget {
  const KanbanDragHandle({
    super.key,
    required this.task,
    this.onDragStarted,
    this.onDragEnd,
  });

  final KanbanTask task;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) => Draggable<KanbanTask>(
    data: task,
    feedback: KanbanDragFeedback(task: task),
    onDragStarted: onDragStarted,
    onDragEnd: (_) => onDragEnd?.call(),
    child: Tooltip(
      message: 'Drag to move',
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.drag_indicator,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    ),
  );
}

/// A draggable that only a mouse or trackpad starts, at once.
class _PointerDraggable extends Draggable<KanbanTask> {
  const _PointerDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => ImmediateMultiDragGestureRecognizer(
    supportedDevices: {PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
  )..onStart = onStart;
}

/// A draggable that only a finger or stylus starts, after a long press.
class _TouchDraggable extends LongPressDraggable<KanbanTask> {
  const _TouchDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  });

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) =>
      DelayedMultiDragGestureRecognizer(
          delay: delay,
          supportedDevices: {PointerDeviceKind.touch, PointerDeviceKind.stylus},
        )
        ..onStart = (position) {
          final drag = onStart(position);
          if (drag != null && hapticFeedbackOnStart) {
            HapticFeedback.selectionClick();
          }
          return drag;
        };
}

/// Fades and grows its child in when it first appears, if [animate]: a card
/// that another client just moved here, arriving where it can be seen.
class KanbanArrival extends StatefulWidget {
  const KanbanArrival({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<KanbanArrival> createState() => _KanbanArrivalState();
}

class _KanbanArrivalState extends State<KanbanArrival>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _animation.forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      // The size transition loosens its child, which would shrink the card
      // to its content instead of the column.
      child: FadeTransition(
        opacity: curved,
        child: SizedBox(width: double.infinity, child: widget.child),
      ),
    );
  }
}
