import 'dart:io';

import 'files_failure.dart';
import 'files_models.dart';
import 'files_preview_kind.dart';

/// The state of the folder the page lists.
sealed class FolderState {
  const FolderState();
}

class FolderLoading extends FolderState {
  const FolderLoading();
}

class FolderReady extends FolderState {
  const FolderReady();
}

class FolderFailed extends FolderState {
  const FolderFailed(this.kind);

  final FilesFailure kind;
}

/// The state of the selected file's preview.
sealed class PreviewState {
  const PreviewState();
}

class PreviewIdle extends PreviewState {
  const PreviewIdle();
}

/// A read or a download is running. [received] and [total] are the download's
/// progress; [total] is null when the server sent no length.
class PreviewLoading extends PreviewState {
  const PreviewLoading({this.received, this.total});

  final int? received;
  final int? total;
}

/// The headers say the file is [bytes] long, from 50 MB: ask before going on.
class PreviewConfirmSize extends PreviewState {
  const PreviewConfirmSize(this.bytes);

  final int bytes;
}

/// The file's name looks secret: ask before requesting anything.
class PreviewConfirmSecret extends PreviewState {
  const PreviewConfirmSecret();
}

/// A text, code or Markdown file's text.
class PreviewText extends PreviewState {
  const PreviewText(this.kind, this.file);

  final FilePreviewKind kind;
  final FsTextFile file;
}

/// An image, downloaded to the cache.
class PreviewImage extends PreviewState {
  const PreviewImage(this.file);

  final File file;
}

/// What is known of a file that is not shown inline: a PDF or other file,
/// text that was binary after all, a file too large for `read-text`, or a
/// download the user cancelled. Nothing is fetched for it until Save, Share
/// or Open with….
class PreviewDetails extends PreviewState {
  const PreviewDetails(this.kind, {this.size, this.tooLargeForText = false});

  final FilePreviewKind kind;

  /// Bytes, once a header or `read-text` said.
  final int? size;

  /// `read-text` answered 413: show "This file is too large to open here."
  final bool tooLargeForText;
}

class PreviewFailed extends PreviewState {
  const PreviewFailed(this.kind);

  final FilesFailure kind;
}

/// What the user chose to do with a file's bytes.
enum FileAction {
  save('save'),
  share('share'),
  openWith('open_with');

  const FileAction(this.slug);

  /// A fixed name for telemetry.
  final String slug;
}
