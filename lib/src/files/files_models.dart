import 'files_failure.dart';
import 'server_path.dart';

/// What a Files call answered: the value, that the server has no `/api/fs`
/// routes, or why it failed. Calls return one of these and never throw.
sealed class FilesResult<T> {
  const FilesResult();
}

class FilesOk<T> extends FilesResult<T> {
  const FilesOk(this.value);

  final T value;
}

/// An older Hermes: the route answered 404 or 405.
class FilesUnsupported<T> extends FilesResult<T> {
  const FilesUnsupported();
}

class FilesFailed<T> extends FilesResult<T> {
  const FilesFailed(this.kind);

  final FilesFailure kind;
}

/// One row of a folder listing. The path is the one the server returned.
class FsEntry {
  const FsEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
  });

  final String name;
  final ServerPath path;

  /// False for a symlink to a folder on a local profile; opening it answers
  /// 400 and the page then lists it as a folder.
  final bool isDirectory;
}

/// A folder's entries in the server's order (folders first), without the rows
/// that did not fit.
class FsListing {
  const FsListing({required this.entries, this.skipped = 0});

  final List<FsEntry> entries;

  /// Rows left out: not an object, no name or path, a path that is not
  /// absolute, or one outside the folder the page is confined to.
  final int skipped;
}

/// The answer of `read-text`: at most 512 KB of a file.
class FsTextFile {
  const FsTextFile({
    required this.text,
    required this.byteSize,
    this.truncated = false,
    this.binary = false,
    this.language,
    this.mimeType,
  });

  final String text;
  final int byteSize;
  final bool truncated;
  final bool binary;
  final String? language;
  final String? mimeType;
}

/// How a streamed download ended.
class FsDownload {
  const FsDownload({
    required this.bytes,
    this.contentLength,
    this.declined = false,
  });

  /// Bytes written to the sink.
  final int bytes;

  /// From the response headers; null when the server sent none (an SSH
  /// workspace).
  final int? contentLength;

  /// The caller stopped it after the headers, before any body was written.
  final bool declined;
}
