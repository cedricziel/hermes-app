enum LogLevel { debug, info, warning, error, critical }

/// One entry of a Hermes log. A line that does not start like an entry (a
/// traceback line) joins the entry before it as a continuation.
class LogLine {
  const LogLine({
    required this.raw,
    this.time,
    this.level,
    this.source,
    this.message,
    this.continuation = const [],
  });

  /// The line as Hermes wrote it.
  final String raw;
  final String? time;
  final LogLevel? level;
  final String? source;
  final String? message;
  final List<String> continuation;

  /// True for an entry whose header could not be read and that has no entry
  /// before it to join.
  bool get isHeaderless => time == null;

  static final _pattern = RegExp(
    r'^(\S+ \S+) (DEBUG|INFO|WARNING|ERROR|CRITICAL)(?: \[[^\]]*\])? (\S+): (.*)$',
  );

  static LogLine? _parseOne(String raw) {
    final m = _pattern.firstMatch(raw);
    if (m == null) return null;
    return LogLine(
      raw: raw,
      time: m.group(1),
      level: LogLevel.values.byName(m.group(2)!.toLowerCase()),
      source: m.group(3),
      message: m.group(4),
    );
  }

  /// Groups [raw] lines, oldest first as the server sends them, into entries.
  /// Never throws.
  static List<LogLine> parseAll(Iterable<String> raw) {
    final out = <LogLine>[];
    for (final line in raw) {
      final entry = _parseOne(line);
      if (entry != null) {
        out.add(entry);
      } else if (out.isEmpty) {
        out.add(LogLine(raw: line));
      } else {
        final last = out.removeLast();
        out.add(
          LogLine(
            raw: last.raw,
            time: last.time,
            level: last.level,
            source: last.source,
            message: last.message,
            continuation: [...last.continuation, line],
          ),
        );
      }
    }
    return out;
  }
}
