import 'package:flutter/widgets.dart';

/// Counts the elements that rebuild while [action] runs: `inside` those below
/// a widget of type [T], `roots` those whose own widget is a [T].
///
/// Flutter calls `debugOnRebuildDirtyWidget` for every element that rebuilds,
/// whether it was marked dirty or its parent gave it a new widget; an element
/// whose parent hands it the identical widget is not rebuilt and not counted.
Future<({int inside, int roots})> countRebuildsBelow<T extends Widget>(
  Future<void> Function() action,
) async {
  final previous = debugOnRebuildDirtyWidget;
  var inside = 0;
  var roots = 0;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    previous?.call(element, builtOnce);
    if (element.widget is T) roots++;
    var below = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is T) {
        below = true;
        return false;
      }
      return true;
    });
    if (below) inside++;
  };
  try {
    await action();
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
  return (inside: inside, roots: roots);
}
