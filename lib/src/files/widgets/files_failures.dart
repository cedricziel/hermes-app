import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/state_message.dart';
import 'files_metrics.dart';

/// Why a folder shows no list. Each has its words, an icon and at most one
/// way forward; none is told by colour alone.
enum FolderProblem {
  /// No answer, or no network.
  unreachable,

  /// ENOENT or a 404: the folder is gone.
  gone,

  /// EACCES or a 403.
  noPermission,

  /// The server shares only one fixed folder and this is not in it.
  fixedFolder,

  /// An SSH workspace that does not answer.
  workspaceDown,

  /// A link to a folder above the chat's highest folder.
  outside,

  /// The server rejected the folder or the chat's profile.
  notAccepted,
}

/// Why a file shows no content.
enum FileProblem {
  /// A 403.
  notShared,

  /// A 404.
  gone,

  /// A 409: a database the server has open.
  busy,

  /// A 400: a folder or special file.
  notAFile,

  /// Anything else.
  couldntOpen,

  /// A download that ended early.
  incomplete,
}

Widget _action(BuildContext context, String label, VoidCallback? onPressed) =>
    OutlinedButton(
      onPressed: onPressed,
      style: FilesMetrics.of(context).buttonStyle(),
      child: Text(label),
    );

/// A failure is announced when it appears, without taking focus. It scrolls,
/// so at the largest text size nothing is cut off.
Widget _announced(Widget message) => Semantics(
  container: true,
  liveRegion: true,
  child: scrollingMessage(message),
);

/// A [StateMessage] that stays centred when it fits and scrolls when the
/// text size makes it taller than the room.
Widget scrollingMessage(Widget message) => LayoutBuilder(
  builder: (context, box) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: box.maxHeight),
      child: message,
    ),
  ),
);

/// A folder that cannot be shown, as a [StateMessage] with an icon, the
/// words and the one action that helps.
class FolderProblemView extends StatelessWidget {
  const FolderProblemView({
    super.key,
    required this.problem,
    this.atHighest = false,
    this.onTryAgain,
    this.onUp,
    this.onGoBack,
  });

  final FolderProblem problem;

  /// The folder is the highest one: a gone folder offers Try again instead
  /// of Up, and there is no folder above to go to.
  final bool atHighest;
  final VoidCallback? onTryAgain;
  final VoidCallback? onUp;
  final VoidCallback? onGoBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, title, detail) = switch (problem) {
      FolderProblem.unreachable => (
        const AppIconSet(Icons.cloud_off_outlined, CupertinoIcons.wifi_slash),
        l10n.filesProblemUnreachable,
        null,
      ),
      FolderProblem.gone => (
        const AppIconSet(
          Icons.folder_off_outlined,
          CupertinoIcons.folder_badge_minus,
        ),
        l10n.filesProblemGone,
        null,
      ),
      FolderProblem.noPermission => (
        AppIcons.lock,
        l10n.filesProblemNoPermission,
        null,
      ),
      FolderProblem.fixedFolder => (
        AppIcons.shield,
        l10n.filesProblemFixedFolder,
        l10n.filesProblemFixedFolderDetail,
      ),
      FolderProblem.workspaceDown => (
        AppIcons.server,
        l10n.filesProblemWorkspaceDown,
        l10n.filesProblemWorkspaceDownDetail,
      ),
      FolderProblem.outside => (
        AppIcons.blocked,
        l10n.filesProblemOutside,
        null,
      ),
      FolderProblem.notAccepted => (
        AppIcons.error,
        l10n.filesProblemNotAccepted,
        l10n.filesProblemNotAcceptedDetail,
      ),
    };
    final action = switch (problem) {
      FolderProblem.unreachable || FolderProblem.workspaceDown => _action(
        context,
        l10n.filesActionTryAgain,
        onTryAgain,
      ),
      FolderProblem.gone =>
        atHighest
            ? _action(context, l10n.filesActionTryAgain, onTryAgain)
            : _action(context, l10n.filesActionUp, onUp),
      FolderProblem.noPermission =>
        atHighest ? null : _action(context, l10n.filesActionUp, onUp),
      FolderProblem.outside => _action(
        context,
        l10n.filesActionGoBack,
        onGoBack,
      ),
      FolderProblem.fixedFolder || FolderProblem.notAccepted => null,
    };
    return _announced(
      StateMessage(icon: icon, title: title, detail: detail, action: action),
    );
  }
}

/// A file that cannot be shown, in the place of its content.
class FilePreviewFailure extends StatelessWidget {
  const FilePreviewFailure({super.key, required this.problem, this.onTryAgain});

  final FileProblem problem;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, title, detail) = switch (problem) {
      FileProblem.notShared => (
        AppIcons.lock,
        l10n.filesFailureNotShared,
        null,
      ),
      FileProblem.gone => (
        const AppIconSet(Icons.search_off, CupertinoIcons.search),
        l10n.filesFailureGone,
        null,
      ),
      FileProblem.busy => (
        const AppIconSet(Icons.hourglass_empty, CupertinoIcons.hourglass),
        l10n.filesFailureBusy,
        null,
      ),
      FileProblem.notAFile => (
        AppIcons.blocked,
        l10n.filesFailureNotAFile,
        null,
      ),
      FileProblem.couldntOpen => (
        AppIcons.error,
        l10n.filesFailureCouldntOpen,
        null,
      ),
      FileProblem.incomplete => (
        AppIcons.warning,
        l10n.filesFailureIncomplete,
        l10n.filesFailureIncompleteDetail,
      ),
    };
    final retry = switch (problem) {
      FileProblem.busy || FileProblem.couldntOpen || FileProblem.incomplete =>
        _action(context, l10n.filesActionTryAgain, onTryAgain),
      _ => null,
    };
    return _announced(
      StateMessage(icon: icon, title: title, detail: detail, action: retry),
    );
  }
}
