enum DoctorItemKind { passed, warning, problem }

class DoctorItem {
  const DoctorItem({
    required this.kind,
    required this.text,
    this.detail,
    this.note,
  });

  final DoctorItemKind kind;

  /// The line without its marker, or its leading part when the server put a
  /// two-space gap before a detail.
  final String text;
  final String? detail;

  /// A `→` line under this item.
  final String? note;

  DoctorItem withNote(String note) =>
      DoctorItem(kind: kind, text: text, detail: detail, note: note);
}

class DoctorSection {
  const DoctorSection({
    required this.title,
    this.items = const [],
    this.other = const [],
  });

  final String title;
  final List<DoctorItem> items;

  /// Lines the parser did not recognise, kept as they are.
  final List<String> other;
}

/// Hermes' `doctor` output, read into sections and the list of things to fix.
class DoctorReport {
  const DoctorReport({
    this.sections = const [],
    this.fixes = const [],
    this.trailing = const [],
    this.allPassed = false,
    this.unknownLines = 0,
  });

  final List<DoctorSection> sections;

  /// The numbered lines after "Found N issue(s) to address:".
  final List<String> fixes;

  /// Lines after "Found N issue(s)" that are not numbered fixes, as written.
  final List<String> trailing;
  final bool allPassed;

  /// How many lines no rule matched.
  final int unknownLines;

  int get problems => _count(DoctorItemKind.problem);
  int get warnings => _count(DoctorItemKind.warning);
  int get passed => _count(DoctorItemKind.passed);

  int _count(DoctorItemKind kind) => sections.fold(
    0,
    (n, s) => n + s.items.where((i) => i.kind == kind).length,
  );

  static final _ansi = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]');

  /// [line] as the report reads it: no ANSI escapes, no emoji selectors, no
  /// trailing space.
  static String clean(String line) => line
      .replaceAll(_ansi, '')
      // Format characters (bidi controls, zero-width spaces and joiners) and
      // emoji selectors draw nothing or reorder text, so what is shown and
      // what is copied could differ.
      .replaceAll(
        RegExp(r'[\p{Cf}\u2028\u2029\uFE0E\uFE0F]', unicode: true),
        '',
      )
      .trimRight();

  /// The cleaned, non-empty [lines] that [report] does not account for: not
  /// a rule, not the "Found N issue(s)" line and not a numbered fix it
  /// listed. Shown as written when the output had no sections to put them in.
  static List<String> leftover(List<String> lines, DoctorReport report) {
    final fixes = report.fixes.toSet();
    final out = <String>[];
    for (final raw in lines) {
      final line = clean(raw);
      final text = line.trim();
      if (text.isEmpty || _rule.hasMatch(text) || _found.hasMatch(text)) {
        continue;
      }
      final fix = _numbered.firstMatch(line)?.group(1);
      if (fix != null && fixes.contains(fix)) continue;
      out.add(text);
    }
    return out;
  }

  static final _header = RegExp(r'^=== doctor started\b');
  static final _found = RegExp(r'Found \d+ issue', caseSensitive: false);
  static final _numbered = RegExp(r'^\s*\d+\.\s+(.*\S)\s*$');
  static final _rule = RegExp(r'^[\s─━═\-=_*│|┌┐└┘├┤┬┴┼╔╗╚╝╠╣╦╩╬+]+$');

  /// Reads the lines of a doctor run: only those after the last
  /// `=== doctor started` header, without ANSI escapes. Never throws.
  static DoctorReport parse(List<String> lines) {
    final start = lines.lastIndexWhere(_header.hasMatch);
    final run = start < 0 ? lines : lines.sublist(start + 1);

    final sections = <DoctorSection>[];
    final fixes = <String>[];
    final trailing = <String>[];
    var allPassed = false;
    var unknown = 0;
    var inFixes = false;

    // Section being built; null until the first `◆` line.
    String? title;
    var items = <DoctorItem>[];
    var other = <String>[];
    void close() {
      final current = title;
      if (current != null) {
        sections.add(DoctorSection(title: current, items: items, other: other));
      }
      items = [];
      other = [];
    }

    for (final raw in run) {
      final line = clean(raw);
      final text = line.trim();
      if (text.isEmpty || _rule.hasMatch(text)) continue;
      if (text.toLowerCase().contains('all checks passed')) {
        allPassed = true;
        continue;
      }
      if (_found.hasMatch(text)) {
        inFixes = true;
        continue;
      }
      if (inFixes) {
        final m = _numbered.firstMatch(line);
        if (m != null) {
          fixes.add(m.group(1)!);
        } else {
          trailing.add(text);
          unknown++;
        }
        continue;
      }
      if (text.startsWith('◆')) {
        close();
        title = text.substring(1).trim();
        continue;
      }
      final kind = switch (text[0]) {
        '✓' => DoctorItemKind.passed,
        '⚠' => DoctorItemKind.warning,
        '✗' => DoctorItemKind.problem,
        _ => null,
      };
      if (kind != null && title != null) {
        final body = text.substring(1).trim();
        final gap = body.indexOf('  ');
        items.add(
          gap > 0
              ? DoctorItem(
                  kind: kind,
                  text: body.substring(0, gap),
                  detail: body.substring(gap).trim(),
                )
              : DoctorItem(kind: kind, text: body),
        );
        continue;
      }
      if (text.startsWith('→') && items.isNotEmpty) {
        items[items.length - 1] = items.last.withNote(text.substring(1).trim());
        continue;
      }
      if (title == null) {
        // The ASCII banner and anything before the first section.
        continue;
      }
      other.add(text);
      unknown++;
    }
    close();
    return DoctorReport(
      sections: sections,
      fixes: fixes,
      trailing: trailing,
      allPassed: allPassed,
      unknownLines: unknown,
    );
  }
}
