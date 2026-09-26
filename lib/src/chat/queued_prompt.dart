import '../share/shared_item.dart';

/// A prompt the user sent while the thread was still replying, held until
/// the reply ends.
class QueuedPrompt {
  const QueuedPrompt(this.text, this.files);

  final String text;
  final List<SharedFile> files;
}
