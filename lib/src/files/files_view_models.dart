import 'dart:io';

import 'package:flutter/painting.dart' show FileImage;

import 'files_controller.dart';
import 'files_failure.dart';
import 'files_models.dart';
import 'files_preview_kind.dart';
import 'files_state.dart';
import 'widgets/file_previews.dart';
import 'widgets/file_row.dart';
import 'widgets/files_browser_view.dart';
import 'widgets/files_failures.dart';
import 'widgets/files_preview_body.dart';

/// What a file's details can offer on this platform: Share exists on iOS and
/// Android, Open with… on Android and desktop (never on iOS, where the share
/// sheet does it), and a PDF's Open is Quick Look on a Mac.
class FilesPlatformActions {
  const FilesPlatformActions({this.share = false, this.openWith = false});

  const FilesPlatformActions.none() : this();

  final bool share;
  final bool openWith;
}

FileRowModel rowModelOf(FilesController controller, FsEntry entry) =>
    FileRowModel(
      name: entry.name,
      isFolder: entry.isDirectory,
      looksSecret: controller.isSecret(entry),
      path: entry.path,
    );

/// The list area's state for [controller]'s folder.
FolderViewState folderViewStateOf(FilesController controller) {
  switch (controller.folderState) {
    case FolderLoading():
      return const FolderViewLoading();
    case FolderFailed(:final kind):
      return FolderViewProblem(
        folderProblemFor(kind),
        atHighest: !controller.canGoUp,
      );
    case FolderReady():
      final shown = controller.shownEntries;
      final total = controller.entryCount;
      return FolderViewReady(
        rows: [for (final e in shown) rowModelOf(controller, e)],
        hasHiddenFiles: shown.isEmpty && controller.hasHiddenEntries,
        totalCount: total > shown.length ? total : null,
        stale: controller.stale,
        showServerFolderNote: controller.startedFromServerDefault,
      );
  }
}

/// Why a folder cannot be shown, in the words the list area has.
FolderProblem folderProblemFor(FilesFailure kind) => switch (kind) {
  FilesFailure.missing => FolderProblem.gone,
  FilesFailure.notAllowed => FolderProblem.noPermission,
  FilesFailure.fixedFolder => FolderProblem.fixedFolder,
  FilesFailure.workspaceDown => FolderProblem.workspaceDown,
  FilesFailure.outside => FolderProblem.outside,
  FilesFailure.badRequest ||
  FilesFailure.notAFile ||
  FilesFailure.tooLarge => FolderProblem.notAccepted,
  FilesFailure.unreachable ||
  FilesFailure.busy ||
  FilesFailure.unreadable ||
  FilesFailure.cancelled => FolderProblem.unreachable,
};

/// Why a file cannot be shown, in the words the preview has.
FileProblem fileProblemFor(FilesFailure kind) => switch (kind) {
  FilesFailure.notAllowed || FilesFailure.fixedFolder => FileProblem.notShared,
  FilesFailure.missing => FileProblem.gone,
  FilesFailure.busy => FileProblem.busy,
  FilesFailure.notAFile => FileProblem.notAFile,
  _ => FileProblem.couldntOpen,
};

/// The most a `read-text` answer carries, which a truncated text shows.
const kFilesTextBytes = 512 * 1024;

/// The preview area's state for [controller]'s selected file.
FilesPreviewModel previewModelOf(
  FilesController controller, {
  FilesPlatformActions actions = const FilesPlatformActions.none(),
}) {
  final entry = controller.selected;
  final name = entry?.path.name ?? '';
  switch (controller.preview) {
    case PreviewIdle():
      return const FilesPreviewEmpty();
    case PreviewLoading(:final received, :final total):
      return FilesPreviewLoading(received: received, total: total);
    // The question is a dialog over a still preview.
    case PreviewConfirmSize() || PreviewConfirmSecret():
      return const FilesPreviewLoading();
    case PreviewText(:final kind, :final file):
      final truncation = file.truncated
          ? FileTruncation(
              shownBytes: file.byteSize < kFilesTextBytes
                  ? file.byteSize
                  : kFilesTextBytes,
              totalBytes: file.byteSize,
            )
          : null;
      return FilesPreviewShown(switch (kind) {
        FilePreviewKind.markdown => MarkdownContent(
          file.text,
          truncation: truncation,
        ),
        FilePreviewKind.code => CodeContent(file.text, truncation: truncation),
        _ => TextContent(file.text, truncation: truncation),
      });
    case PreviewImage(:final file):
      return FilesPreviewShown(ImageContent(FileImage(file), label: name));
    case PreviewDetails(:final kind, :final size, :final tooLargeForText):
      final canOpen = entry != null && controller.canOpenWith(entry);
      if (kind == FilePreviewKind.pdf) {
        return FilesPreviewDetails(
          name: name,
          size: size,
          primary: FilesDetailsActionKind.open,
          secondary: [FilesDetailsActionKind.save],
        );
      }
      return FilesPreviewDetails(
        name: name,
        size: size ?? controller.knownSize,
        tooLarge: tooLargeForText,
        primary: FilesDetailsActionKind.save,
        secondary: tooLargeForText
            ? const []
            : [
                if (actions.share) FilesDetailsActionKind.share,
                if (actions.openWith && canOpen)
                  FilesDetailsActionKind.openWith,
              ],
      );
    case PreviewFailed(:final kind):
      return FilesPreviewFailed(fileProblemFor(kind));
  }
}

/// The folder's own name for the page title: the last segment, or the path
/// of a filesystem root.
String folderTitleOf(FilesController controller, String fallback) {
  final folder = controller.folder;
  if (folder == null) return fallback;
  return folder.isRoot ? folder.value : folder.name;
}

/// The file a [FileImage] shows, for a test.
File? imageFileOf(FilesPreviewModel model) {
  if (model is FilesPreviewShown) {
    final content = model.content;
    if (content is ImageContent && content.image is FileImage) {
      return (content.image as FileImage).file;
    }
  }
  return null;
}
