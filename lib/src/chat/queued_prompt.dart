import '../share/shared_item.dart';

/// A prompt the user sent while the thread was still replying, held until
/// the reply ends.
class QueuedPrompt {
  const QueuedPrompt(this.text, this.files, {this.displayText});

  final String text;
  final List<SharedFile> files;

  /// The user-facing form when [text] contains a command-expanded prompt.
  final String? displayText;
}
