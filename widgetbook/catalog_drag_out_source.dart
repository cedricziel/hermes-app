import 'package:flutter/material.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:provider/provider.dart';

/// Stands in for the macOS drag-out source in the catalog, where there is no
/// native drag session: a draggable widget shows a grab cursor and a hint
/// instead of starting one, and a widget with nothing to hand out is left
/// alone, as the app leaves it.
class CatalogDragOutSource implements DragOutSource {
  const CatalogDragOutSource();

  @override
  Widget wrap({
    required DragOutKind kind,
    required DragOutItem? Function() item,
    required Widget child,
  }) {
    // A file shows its name; text brings its own hint (the message grip).
    final (name, hasItem) = switch (item()) {
      DragOutFile(:final name) => (name, true),
      DragOutText() => (null, true),
      null => (null, false),
    };
    if (!hasItem) return child;
    final draggable = MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: child,
    );
    return name == null
        ? draggable
        : Tooltip(message: 'Drags out as $name', child: draggable);
  }
}

/// Provides [CatalogDragOutSource] above [child].
Widget withCatalogDragOut(Widget child) => Provider<DragOutSource?>.value(
  value: const CatalogDragOutSource(),
  child: child,
);
