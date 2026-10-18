/// A reported automatic recall, not the contents of the retrieved notes.
/// Hermes' current status callback sends only the human-readable indicator.
class MemoryRecall {
  const MemoryRecall({required this.summary, required this.receivedAt});

  final String summary;
  final DateTime receivedAt;

  // MemoryManager.describe_recall() emits one or more provider indicators,
  // separated by two spaces. Do not classify arbitrary memory-related work
  // (or a message waiting on approval) as a completed recall.
  static final _indicator = RegExp(
    r'^.+ — recalled (?:[0-9]+ memor(?:y|ies)|relevant memory)$',
  );

  static MemoryRecall? fromStatus(String text, {DateTime? receivedAt}) {
    if (text.length > 4096 ||
        text.trim().split('  ').any((part) => !_indicator.hasMatch(part))) {
      return null;
    }
    return MemoryRecall(
      summary: text.trim().replaceFirst(RegExp(r'^🧠\s*'), ''),
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }
}
