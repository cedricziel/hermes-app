import '../share/shared_item.dart';
import 'queue_storage/queue_record.dart';

/// A prompt the user sent while the thread was still replying, held until
/// the reply ends.
class QueuedPrompt {
  const QueuedPrompt(
    this.text,
    this.files, {
    this.displayText,
    this.durable,
    this.scope,
    this.submitting = false,
  });

  final QueueRecord? durable;
  final QueueScope? scope;
  final bool submitting;
  bool get uncertain =>
      durable?.state == QueueRecordState.submissionStarted && !submitting;
  int get attachmentCount => durable?.attachments.length ?? files.length;
  Iterable<String> get attachmentNames =>
      durable?.attachments.map((file) => file.name) ??
      files.map((file) => file.name);

  final String text;
  final List<SharedFile> files;

  /// The user-facing form when [text] contains a command-expanded prompt.
  final String? displayText;
}
