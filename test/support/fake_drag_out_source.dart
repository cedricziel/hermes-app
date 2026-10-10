import 'package:flutter/widgets.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';

/// A [DragOutSource] that records what it was asked to wrap and lets a test
/// start a drag by hand, in place of the plugin and a native drag session.
class FakeDragOutSource implements DragOutSource {
  final wraps = <FakeWrap>[];

  @override
  Widget wrap({
    required DragOutKind kind,
    required DragOutItem? Function() item,
    required Widget child,
  }) {
    wraps.add(FakeWrap(kind, item));
    return child;
  }

  /// The item the most recent wrap would carry if the user started a drag now.
  DragOutItem? get lastItem => wraps.last.item();

  /// The file the most recent wrap would carry; fails the test if it carries
  /// none or something else.
  DragOutFile get lastFile => lastItem! as DragOutFile;
}

class FakeWrap {
  FakeWrap(this.kind, this.item);

  final DragOutKind kind;
  final DragOutItem? Function() item;
}
