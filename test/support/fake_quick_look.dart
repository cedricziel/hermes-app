import 'package:hermes_app/src/chat/media/quick_look.dart';

/// Stands in for the Quick Look panel: remembers what it was asked to show.
class FakeQuickLook implements QuickLook {
  FakeQuickLook({this.available = true, this.shows = true});

  @override
  bool available;

  /// Whether the panel manages to show a file.
  bool shows;

  /// The path the panel shows now, or null when it is closed.
  String? shown;

  /// Every path handed to [preview] or opened by [toggle], in order.
  final previewed = <String>[];

  var closes = 0;

  @override
  Future<bool> preview(String path) async {
    if (!shows) return false;
    previewed.add(path);
    shown = path;
    return true;
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
