import 'files_failure.dart';
import 'widgets/files_failures.dart';

/// The problem a folder failure shows. [lockedDeployment] says a 403 is the
/// boundary of a server shared from one folder.
FolderProblem folderProblemFor(
  FilesFailure kind, {
  bool lockedDeployment = false,
}) => switch (kind) {
  FilesFailure.missing => FolderProblem.gone,
  FilesFailure.notAllowed =>
    lockedDeployment ? FolderProblem.fixedFolder : FolderProblem.noPermission,
  FilesFailure.workspaceDown => FolderProblem.workspaceDown,
  FilesFailure.outside => FolderProblem.outside,
  FilesFailure.badRequest => FolderProblem.notAccepted,
  _ => FolderProblem.unreachable,
};

/// The problem a file failure shows.
FileProblem fileProblemFor(FilesFailure kind) => switch (kind) {
  FilesFailure.notAllowed => FileProblem.notShared,
  FilesFailure.missing => FileProblem.gone,
  FilesFailure.busy => FileProblem.busy,
  FilesFailure.notAFile => FileProblem.notAFile,
  _ => FileProblem.couldntOpen,
};
