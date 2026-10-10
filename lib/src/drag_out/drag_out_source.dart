import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'drag_out_item.dart';

/// Turns a widget into a source of native drags out of the app.
///
/// Widgets never touch the drag plugin: they ask the [DragOutSource] above
/// them, if any, to wrap their child. Use [DragOut] rather than calling
/// [wrap] by hand.
abstract interface class DragOutSource {
  /// [child], made draggable.
  ///
  /// [item] is asked each time the user starts a drag; returning null cancels
  /// that drag and leaves the click or selection to [child]. It builds the
  /// item only: file bytes are read when the receiver asks for them, never at
  /// drag start. [kind] is what telemetry calls the drag.
  Widget wrap({
    required DragOutKind kind,
    required DragOutItem? Function() item,
    required Widget child,
  });
}

/// A source that makes nothing draggable: the one on platforms without
/// drag-out, and in tests.
class NoDragOutSource implements DragOutSource {
  const NoDragOutSource();

  @override
  Widget wrap({
    required DragOutKind kind,
    required DragOutItem? Function() item,
    required Widget child,
  }) => child;
}

/// Makes [child] draggable out of the app as [item], when a [DragOutSource]
/// is provided above it, and is [child] itself otherwise. Conversation
/// windows, the Widgetbook catalog and other platforms provide none.
///
/// ```dart
/// DragOut(
///   kind: DragOutKind.attachment,
///   item: () => DragOutFile(name: 'report.pdf', read: loadBytes),
///   child: card,
/// )
/// ```
class DragOut extends StatelessWidget {
  const DragOut({
    super.key,
    required this.kind,
    required this.item,
    required this.child,
  });

  final DragOutKind kind;

  /// See [DragOutSource.wrap].
  final DragOutItem? Function() item;

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      context.read<DragOutSource?>()?.wrap(
        kind: kind,
        item: item,
        child: child,
      ) ??
      child;
}
