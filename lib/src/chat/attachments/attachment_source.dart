import 'package:flutter/widgets.dart';

import '../../share/shared_item.dart';

/// Where the user can attach something from.
enum AttachOrigin { files, photos, camera }

/// Thrown when an origin cannot deliver, for example a denied camera. The
/// [message] is fit to show to the user.
class AttachmentUnavailable implements Exception {
  const AttachmentUnavailable(this.message);

  final String message;

  @override
  String toString() => 'AttachmentUnavailable: $message';
}

/// Everything that can produce a [SharedFile] for the composer other than the
/// share sheet. It hides the plugins, so the chat only sees files.
abstract interface class AttachmentSource {
  /// The entries of the attach menu, in order.
  List<AttachOrigin> get origins;

  /// Whether the platform lets the user drop files onto the chat and paste
  /// them into the composer.
  bool get acceptsDropAndPaste;

  /// Lets the user choose from [origin]. Empty when they cancel. Throws
  /// [AttachmentUnavailable] when the origin cannot be used.
  Future<List<SharedFile>> pick(AttachOrigin origin);

  /// The image or the files on the clipboard, or empty when it holds neither.
  Future<List<SharedFile>> pasted();

  /// Wraps [child] so files dragged over it report through [onHover] and files
  /// dropped on it through [onDrop]. Returns [child] where drops are not
  /// supported.
  Widget dropTarget({
    required Widget child,
    required ValueChanged<bool> onHover,
    required ValueChanged<List<SharedFile>> onDrop,
  });
}
