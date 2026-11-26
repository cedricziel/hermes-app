import 'dart:math' as math;

import 'chat_models.dart';
import 'tool_result.dart';

/// What the rows of a table are called.
enum RowsUnit { matches, rows }

/// What a note under the table's summary is about. Pure: the words come from
/// the view.
enum RowsNoteKind {
  /// A search that stopped at its limit; [RowsNote.count] is the total found
  /// so far, a lower bound.
  stoppedEarly,

  /// Results Hermes left out because they target files that may hold secrets;
  /// [RowsNote.count] is how many, when its text says.
  heldBack,

  /// Hermes' own `warning`, `_warning` or `limit_reason`, as it came.
  warning,

  /// Hermes' own `_hint`, as it came.
  hint,
}

class RowsNote {
  const RowsNote(this.kind, {this.text = '', this.count});

  final RowsNoteKind kind;

  /// The server's own words.
  final String text;
  final int? count;
}

/// A tool result that is a list of flat rows (strings, numbers, booleans and
/// nulls), read into what the table shows. Pure: no widget, no words. Null
/// from [of] for anything else, so the card falls back to its generic input
/// and result: a nested value, an empty list (except a search with no match),
/// a text that is not JSON.
class RowsResult {
  const RowsResult._({
    required this.columns,
    required this.rows,
    required this.unit,
    this.moreColumns = 0,
    this.total,
    this.notes = const [],
  });

  /// The most columns that show.
  static const maxColumns = 8;

  /// The columns shown, in the order the rows first name them.
  final List<String> columns;

  /// Columns past [maxColumns]: counted, and kept in each row for Copy row.
  final int moreColumns;

  /// Every row with all its keys. A row may lack a key another one has.
  final List<Map<String, Object?>> rows;
  final RowsUnit unit;

  /// How many Hermes found when that is more than [rows] holds.
  final int? total;
  final List<RowsNote> notes;

  /// A search that found nothing.
  bool get isEmpty => rows.isEmpty;

  static final _parsed = Expando<_Parsed>();

  /// The result of [call], parsed once per call: the card asks on every
  /// build, closed ones too.
  static RowsResult? of(ToolCall call) =>
      (_parsed[call] ??= _Parsed(_parse(call))).result;

  static RowsResult? _parse(ToolCall call) {
    final json = toolResultJson(call);
    final search = call.name == 'search_files';
    if (json is List) return _fromRows(json, RowsUnit.rows);
    if (json is! Map) return null;
    final map = _stringKeyed(json);
    if (map == null || _text(map['error']).isNotEmpty) return null;
    final total = _int(map['total_count']);
    final notes = _notes(map, total);
    if (search) return _search(map, notes, total);
    final lists = map.values.whereType<List<Object?>>().toList();
    // The one large value is the rows; whatever else is there is a scalar.
    if (lists.length != 1 ||
        map.values.any((v) => !identical(v, lists.single) && _isNested(v))) {
      return null;
    }
    return _fromRows(lists.single, RowsUnit.rows, notes: notes);
  }

  static RowsResult? _search(
    Map<String, Object?> map,
    List<RowsNote> notes,
    int? total,
  ) {
    // File names and counts per file are answers of another shape.
    if (map.containsKey('files') || map.containsKey('counts')) return null;
    final matches = map['matches'];
    final text = map['matches_text'];
    final List<Object?>? rows;
    if (matches is List<Object?>) {
      rows = matches;
    } else if (text is String &&
        _text(map['matches_format']).startsWith('path-grouped:')) {
      rows = parsePathGrouped(text);
      if (rows == null) return null;
    } else if (total == 0 && !map.containsKey('matches')) {
      rows = const [];
    } else {
      return null;
    }
    return rows.isEmpty
        ? RowsResult._(
            columns: const [],
            rows: const [],
            unit: RowsUnit.matches,
            notes: notes,
          )
        : _fromRows(rows, RowsUnit.matches, notes: notes, total: total);
  }

  static RowsResult? _fromRows(
    List<Object?> list,
    RowsUnit unit, {
    List<RowsNote> notes = const [],
    int? total,
  }) {
    if (list.isEmpty) return null;
    final rows = <Map<String, Object?>>[];
    final columns = <String>{};
    for (final item in list) {
      final row = item is Map ? _stringKeyed(item) : null;
      if (row == null || row.values.any(_isNested)) return null;
      rows.add(row);
      columns.addAll(row.keys);
    }
    if (columns.isEmpty) return null;
    return RowsResult._(
      columns: columns.take(maxColumns).toList(),
      moreColumns: math.max(0, columns.length - maxColumns),
      rows: rows,
      unit: unit,
      total: total != null && total > rows.length ? total : null,
      notes: notes,
    );
  }

  static List<RowsNote> _notes(Map<String, Object?> map, int? total) {
    final omitted = _text(map['_omitted']);
    return [
      if (map['truncated'] == true &&
          map['total_count_is_lower_bound'] == true &&
          total != null)
        RowsNote(RowsNoteKind.stoppedEarly, count: total),
      if (omitted.isNotEmpty)
        RowsNote(
          RowsNoteKind.heldBack,
          text: omitted,
          count: int.tryParse(RegExp(r'^\d+').stringMatch(omitted) ?? ''),
        ),
      for (final key in const ['warning', '_warning', 'limit_reason'])
        if (_text(map[key]).isNotEmpty)
          RowsNote(RowsNoteKind.warning, text: _text(map[key])),
      if (_text(map['_hint']).isNotEmpty)
        RowsNote(RowsNoteKind.hint, text: _text(map['_hint'])),
    ];
  }

  @override
  String toString() =>
      'RowsResult(${rows.length} rows, ${columns.length} columns)';
}

// `[^\n]*`, not `.`: in Dart `.` stops at a carriage return and at U+2028 and
// U+2029, which a hit's content may hold.
final _hit = RegExp(r'^  (\d+): ([^\n]*)$');

/// The rows of a path-grouped block (a path on its own line, then
/// `  <line>: <content>` rows), as `{path, line, content}` maps, or null when
/// any line is neither a path line (not empty, no leading space) nor a row:
/// nothing is guessed.
List<Map<String, Object?>>? parsePathGrouped(String text) {
  final lines = text.split('\n');
  if (lines.last.isEmpty) lines.removeLast();
  final rows = <Map<String, Object?>>[];
  String? path;
  for (final line in lines) {
    final hit = _hit.firstMatch(line);
    final number = int.tryParse(hit?.group(1) ?? '');
    if (hit != null && number != null) {
      if (path == null) return null;
      rows.add({'path': path, 'line': number, 'content': hit.group(2)!});
    } else if (line.isNotEmpty && !line.startsWith(' ')) {
      path = line;
    } else {
      return null;
    }
  }
  return rows;
}

class _Parsed {
  const _Parsed(this.result);

  final RowsResult? result;
}

/// Whether a value is a list or a map, the shape that makes a row not flat.
bool _isNested(Object? value) => value is Map || value is List;

Map<String, Object?>? _stringKeyed(Map<Object?, Object?> map) =>
    map is Map<String, Object?>
    ? map
    : map.keys.every((key) => key is String)
    ? map.cast<String, Object?>()
    : null;

int? _int(Object? value) => value is int ? value : null;

String _text(Object? value) => value is String ? value.trim() : '';
