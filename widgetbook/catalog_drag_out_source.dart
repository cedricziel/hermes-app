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
    final name = switch (item()) {
      DragOutFile(:final name) => name,
      DragOutText() => 'text',
      null => null,
    };
    if (name == null) return child;
    return Tooltip(
      message: 'Drags out as $name',
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }
}

/// Provides [CatalogDragOutSource] above [child].
Widget withCatalogDragOut(Widget child) => Provider<DragOutSource?>.value(
  value: const CatalogDragOutSource(),
  child: child,
);
