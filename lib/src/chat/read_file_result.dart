import 'chat_models.dart';
import 'tool_result.dart';

/// One line of a file as Hermes numbered it.
typedef CodeRow = ({int number, String text});

// `[^\n]*`, not `.`: in Dart `.` stops at a carriage return and at U+2028 and
// U+2029, which a row of a CRLF file or a line of text may hold.
final _numberedRow = RegExp(r'^ *(\d+)\|([^\n]*)$');

/// The rows of [content] (`N|text`, one per line), or null when any line is
/// not one: nothing is guessed.
List<CodeRow>? parseNumberedRows(String content) {
  if (content.isEmpty) return const [];
  final lines = content.split('\n');
  if (lines.last.isEmpty) lines.removeLast();
  final rows = <CodeRow>[];
  for (final line in lines) {
    final match = _numberedRow.firstMatch(line);
    final number = int.tryParse(match?.group(1) ?? '');
    if (match == null || number == null) return null;
    rows.add((number: number, text: match.group(2)!));
  }
  return rows;
}

/// What a `read_file` answer was.
enum ReadFileKind {
  /// Numbered rows of text.
  code,

  /// A file with no text.
  empty,

  /// A read that starts after the last line.
  pastEnd,

  /// A binary file or an image; its content is never kept.
  notText,

  /// Hermes answered with an error.
  failed,

  /// A repeated read that Hermes answered with a stub, not the file.
  unchanged,
}

/// A `read_file` call read into what its view shows. Pure: no widget, no
/// words. Null from [of] for anything that is not the shape the code view
/// expects, so the card falls back to its generic input and result.
class ReadFileResult {
  const ReadFileResult._({
    required this.path,
    required this.kind,
    this.rows = const [],
    this.totalLines,
    this.nextOffset,
    this.fileSize,
    this.truncated = false,
    this.truncatedByBytes = false,
    this.longLinesCut = false,
    this.extractedDocument = false,
    this.maskedText = false,
    this.error = '',
    this.similarFiles = const [],
  });

  final String path;
  final ReadFileKind kind;
  final List<CodeRow> rows;
  final int? totalLines;
  final int? nextOffset;
  final int? fileSize;

  /// The read ended before the end of the file.
  final bool truncated;

  /// The server stopped at its size limit (`truncated_by: bytes`).
  final bool truncatedByBytes;

  /// Hermes cut some lines of the text it returned.
  final bool longLinesCut;

  /// Text taken out of a document (a PDF, a spreadsheet), not the file.
  final bool extractedDocument;

  /// The text holds a marker of a secret Hermes masked.
  final bool maskedText;

  /// Hermes' own words, for a failed read or a file that is not text.
  final String error;
  final List<String> similarFiles;

  int? get firstLine => rows.isEmpty ? null : rows.first.number;
  int? get lastLine => rows.isEmpty ? null : rows.last.number;

  /// Where the next read starts: Hermes' `next_offset`, else the line after
  /// the last one shown.
  int? get nextLine => nextOffset ?? (lastLine == null ? null : lastLine! + 1);

  static const _maskMarkers = ['«redacted', '[REDACTED PRIVATE KEY]'];

  static ReadFileResult? of(ToolCall call) {
    final path = call.args?['path'];
    final data = toolResultMap(call);
    if (path is! String || path.isEmpty || data == null) return null;
    ReadFileResult stub(ReadFileKind kind, {String error = ''}) =>
        ReadFileResult._(
          path: path,
          kind: kind,
          fileSize: _int(data['file_size']),
          error: error,
        );
    if (data['dedup'] == true && data['status'] == 'unchanged') {
      return stub(ReadFileKind.unchanged);
    }
    // A detected binary file carries `error` as well, so this comes first.
    if (data['is_binary'] == true || data['is_image'] == true) {
      return stub(ReadFileKind.notText, error: _text(data['error']));
    }
    final error = _text(data['error']);
    if (error.isNotEmpty) {
      final similar = data['similar_files'];
      return ReadFileResult._(
        path: path,
        kind: ReadFileKind.failed,
        error: error,
        similarFiles: similar is List
            ? similar.whereType<String>().toList()
            : [],
      );
    }
    final content = data['content'];
    if (content is! String) return null;
    final rows = parseNumberedRows(content);
    if (rows == null) return null;
    final totalLines = _int(data['total_lines']);
    final offset = _int(call.args?['offset']) ?? 1;
    return ReadFileResult._(
      path: path,
      rows: rows,
      kind: switch (rows.isEmpty) {
        false => ReadFileKind.code,
        true when offset > 1 && totalLines != null && totalLines < offset =>
          ReadFileKind.pastEnd,
        true => ReadFileKind.empty,
      },
      totalLines: totalLines,
      nextOffset: _int(data['next_offset']),
      fileSize: _int(data['file_size']),
      truncated: data['truncated'] == true,
      truncatedByBytes: data['truncated_by'] == 'bytes',
      longLinesCut: data['truncated_lines'] == true,
      extractedDocument: data['extracted_document'] == true,
      maskedText: _maskMarkers.any(content.contains),
    );
  }

  @override
  String toString() => 'ReadFileResult($path, $kind, ${rows.length} rows)';
}

int? _int(Object? value) => value is int ? value : null;

String _text(Object? value) => value is String ? value.trim() : '';
