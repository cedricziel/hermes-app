/// The two files Hermes keeps built-in memory in.
enum MemoryTab {
  aboutYou('About you', 'USER.md', 'about_you'),
  agentNotes('Agent notes', 'MEMORY.md', 'agent_notes');

  const MemoryTab(this.label, this.file, this.slug);
  final String label, file;

  /// A fixed name for telemetry.
  final String slug;

  /// An entry without a known source is listed under Agent notes, where
  /// Hermes writes by default, so it is never hidden.
  static MemoryTab forSource(String? source) =>
      source == 'profile' ? aboutYou : agentNotes;
}

/// Characters as Hermes counts them: Python's `len`, which is code points.
int characterCount(String text) => text.runes.length;

/// How full one memory file is. Hermes counts a file as the entries' lengths
/// plus 3 for each `"\n§\n"` between two entries.
class MemoryUsage {
  const MemoryUsage({
    required this.used,
    required this.entries,
    this.limit,
    this.lowerBound = false,
  });

  factory MemoryUsage.of(
    Iterable<String> texts, {
    int? limit,
    bool lowerBound = false,
  }) {
    final list = texts.toList();
    return MemoryUsage(
      used:
          list.fold(0, (sum, text) => sum + characterCount(text)) +
          3 * (list.isEmpty ? 0 : list.length - 1),
      entries: list.length,
      limit: limit,
      lowerBound: lowerBound,
    );
  }

  final int used, entries;

  /// Null when the profile's config could not say.
  final int? limit;

  /// Some entry's full text could not be read, so [used] is at least this.
  final bool lowerBound;

  double? get fraction => limit == null ? null : (used / limit!).clamp(0, 1);

  bool get nearlyFull => limit != null && used * 100 >= limit! * 95;

  int? get left => limit == null ? null : limit! - used;

  /// What is left with [draft] in place of the entry [original].
  int? leftWith({required String original, required String draft}) =>
      limit == null
      ? null
      : limit! - (used - characterCount(original) + characterCount(draft));
}

String groupThousands(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
