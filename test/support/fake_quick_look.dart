import 'dart:async';

import 'package:hermes_app/src/chat/media/quick_look.dart';

/// Stands in for the Quick Look panel: remembers what it was asked to show.
class FakeQuickLook implements QuickLook {
  FakeQuickLook({this.shows = true});

  /// Whether the panel manages to show a file.
  bool shows;

  /// The path the panel shows now, or null when it is closed.
  String? shown;

  /// Every path handed to [preview] or opened by [toggle], in order.
  final previewed = <String>[];

  /// Completes when this fake finishes handling a preview request.
  final _previewCompleted = Completer<void>();

  Future<void> get previewCompleted => _previewCompleted.future;

  var closes = 0;

  /// What the system says a double-click interval is; null when it cannot.
  Duration? interval;

  @override
  Future<Duration?> doubleClickInterval() async => interval;

  @override
  Future<bool> preview(String path) async {
    if (shows) {
      previewed.add(path);
      shown = path;
    }
    if (!_previewCompleted.isCompleted) _previewCompleted.complete();
    return shows;
  }

  @override
  Future<QuickLookToggle> toggle(String path) async {
    if (shown == path) {
      shown = null;
      return QuickLookToggle.closed;
    }
    return await preview(path) ? QuickLookToggle.shown : QuickLookToggle.failed;
  }

  @override
  Future<void> close() async {
    closes++;
    shown = null;
  }
}
