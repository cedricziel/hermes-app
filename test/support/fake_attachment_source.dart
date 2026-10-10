import 'package:flutter/widgets.dart';

import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/share/shared_item.dart';

/// An [AttachmentSource] that never touches a plugin channel. Tests decide
/// what each origin returns and drive drops by hand.
class FakeAttachmentSource implements AttachmentSource {
  FakeAttachmentSource({
    this.origins = const [
      AttachOrigin.files,
      AttachOrigin.photos,
      AttachOrigin.camera,
    ],
    this.acceptsDrops = true,
  });

  @override
  final List<AttachOrigin> origins;
  @override
  final bool acceptsDrops;

  /// What [pick] returns per origin; a missing entry means the user cancelled.
  final picks = <AttachOrigin, List<SharedFile>>{};

  /// Thrown by [pick] when set.
  Object? pickFailure;

  /// What [pasted] returns.
  List<SharedFile> clipboard = const [];

  final requested = <AttachOrigin>[];
  var pasteReads = 0;
  var hasDropTarget = false;

  ValueChanged<bool>? _onHover;
  ValueChanged<List<SharedFile>>? _onDrop;

  @override
  Future<List<SharedFile>> pick(AttachOrigin origin) async {
    requested.add(origin);
    final failure = pickFailure;
    if (failure != null) throw failure; // ignore: only_throw_errors
    return picks[origin] ?? const [];
  }

  /// What [inserted] returns for any keyboard content.
  List<SharedFile> keyboardImage = const [];

  @override
  Future<bool> hasFilesToPaste() async => clipboard.isNotEmpty;

  @override
  Future<List<SharedFile>> inserted(KeyboardInsertedContent content) async =>
      keyboardImage;

  @override
  Future<List<SharedFile>> pasted() async {
    pasteReads++;
    return clipboard;
  }

  @override
  Widget dropTarget({
    required Widget child,
    required ValueChanged<bool> onHover,
    required ValueChanged<List<SharedFile>> onDrop,
  }) {
    hasDropTarget = true;
    _onHover = onHover;
    _onDrop = onDrop;
    return child;
  }

  void dragOver(bool over) => _onHover!(over);

  void drop(List<SharedFile> files) => _onDrop!(files);
}
