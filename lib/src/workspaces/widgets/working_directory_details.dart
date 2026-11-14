import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../chat/chat_workspace_state.dart';
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/files_spinner.dart';
import '../../files/widgets/server_path_text.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/named_icon_button.dart';
import 'workspace_widget_support.dart';

/// Where a chat runs, in full: the body of the "Working folder" sheet (a
/// dialog on a Mac and in wide windows).
///
/// A title and, with [onClose], a close button; then the outcome of a folder
/// move as a banner (see [move]); then the Folder, Path (the whole path,
/// wrapped, in monospace, selectable on a Mac), Branch and Project rows, each
/// left out when unknown; an outlined "Change folder…" that only opens the
/// picker; and a footnote.
///
/// A disabled button always has its reason under it, with an icon, and the
/// reason is also the button's accessible description: "Wait for the reply to
/// finish.", "You're offline.", "Changing the folder…", "Checking the
/// folder…". With [canChange] false (an older server) there is no button, and
/// in a [conversationWindow] there is none and the footnote points to the main
/// window. At a large text size the rows stack their label over the value and
/// the sheet scrolls. It takes plain values and callbacks.
class WorkingDirectoryDetails extends StatelessWidget {
  const WorkingDirectoryDetails({
    super.key,
    required this.folderName,
    required this.path,
    this.branch,
    this.projectName,
    this.homeFolder = false,
    this.replying = false,
    this.offline = false,
    this.canChange = true,
    this.conversationWindow = false,
    this.move = WorkspaceMoveState.idle,
    this.moveTarget,
    this.moveTimedOut = false,
    this.onChange,
    this.onTryAgain,
    this.onCheckAgain,
    this.onClose,
  });

  /// The folder's name and full path on the server: where the chat runs now.
  final String folderName;
  final String path;
  final String? branch;

  /// The Hermes project the folder belongs to, when one does.
  final String? projectName;

  /// The folder is the server's home folder or `/`.
  final bool homeFolder;

  /// A reply is running, so the folder cannot change.
  final bool replying;
  final bool offline;

  /// The server can move a chat to another folder. False: no button.
  final bool canChange;

  /// A conversation window: no button, and the footnote names the main window.
  final bool conversationWindow;

  /// How a move of this chat's folder stands.
  final WorkspaceMoveState move;

  /// The folder the move goes to, as a path or a name.
  final String? moveTarget;

  /// While checking: Hermes has not answered for 10 seconds.
  final bool moveTimedOut;

  /// Opens the picker.
  final VoidCallback? onChange;

  /// Offers the change again after "The folder wasn't changed."
  final VoidCallback? onTryAgain;

  /// Reads the chat's folder again after "Couldn't confirm the change".
  final VoidCallback? onCheckAgain;
  final VoidCallback? onClose;

  String? _reason(AppLocalizations l10n) {
    if (move.phase == WorkspaceMovePhase.moving) {
      return l10n.workspacesReasonChanging;
    }
    if (move.phase == WorkspaceMovePhase.checking) {
      return l10n.workspacesReasonChecking;
    }
    if (replying) return l10n.workspacesReasonReplying;
    if (offline) return l10n.workspacesReasonOffline;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final files = FilesMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final banner = _banner(context, l10n);
    final reason = _reason(l10n);
    final showButton = canChange && !conversationWindow;
    final busy = move.inFlight;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.gutter,
        12,
        metrics.gutter,
        metrics.gutter + 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.rowPadding / 2,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.workspacesDetailsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              if (onClose != null)
                NamedIconButton(
                  key: const Key('working-directory-close'),
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  icon: AppIcons.close,
                  iconSize: files.pointer ? 16 : 22,
                  padding: EdgeInsets.zero,
                  style: files.iconButtonStyle(),
                  onPressed: onClose,
                ),
            ],
          ),
          if (banner != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: banner),
          GroupedSection(
            dividerIndent: metrics.rowPadding,
            children: [
              _DetailRow(
                label: l10n.workspacesDetailsFolder,
                trailing: busy ? const FilesSpinner(size: 18) : null,
                child: _Value(
                  Text(folderName),
                  warning: homeFolder ? l10n.workspacesHomeFolderNote : null,
                ),
              ),
              _DetailRow(
                label: l10n.workspacesDetailsPath,
                child: ServerPathText.text(
                  path,
                  wrap: true,
                  selectable: mac,
                  style: TextStyle(fontSize: metrics.subtitleSize),
                ),
              ),
              if (branch != null && branch!.isNotEmpty)
                _DetailRow(
                  label: l10n.workspacesDetailsBranch,
                  child: _Value(Text(branch!, style: _mono(metrics))),
                ),
              if (projectName != null)
                _DetailRow(
                  label: l10n.workspacesDetailsProject,
                  child: _Value(Text(projectName!)),
                ),
            ],
          ),
          if (showButton) ...[
            const SizedBox(height: 16),
            MergeSemantics(
              child: Semantics(
                hint: reason,
                child: OutlinedButton(
                  key: const Key('working-directory-change'),
                  onPressed: reason == null ? onChange : null,
                  style: files.buttonStyle(fullWidth: true),
                  child: Text(l10n.workspacesDetailsChange),
                ),
              ),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: AppIcon(
                          AppIcons.info,
                          size: workspaceGlyphSize(
                            context,
                            metrics.footerSize + 2,
                          ),
                          color: muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: metrics.footerSize,
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(metrics.rowPadding / 2, 12, 8, 0),
            child: Text(
              conversationWindow
                  ? l10n.workspacesDetailsFootnoteWindow
                  : l10n.workspacesDetailsFootnote,
              style: TextStyle(fontSize: metrics.footerSize, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _mono(GroupedMetrics metrics) =>
      TextStyle(fontFamily: kServerPathFont, fontSize: metrics.subtitleSize);

  Widget? _banner(BuildContext context, AppLocalizations l10n) {
    final folder = workspaceFolderName(move.folder ?? moveTarget ?? '');
    final target = workspaceShortName(
      workspaceFolderName(moveTarget ?? ''),
      max: 32,
    );
    final stillIn = workspaceShortName(folderName, max: 32);
    TextButton action(String label, VoidCallback? onPressed) => TextButton(
      onPressed: onPressed,
      style: FilesMetrics.of(context).buttonStyle(),
      child: Text(label),
    );
    return switch (move.phase) {
      WorkspaceMovePhase.idle => null,
      WorkspaceMovePhase.moving => AppBanner(
        tone: AppBannerTone.neutral,
        title: l10n.workspacesMoveChanging(target),
        detail: l10n.workspacesMoveSendHeld,
      ),
      WorkspaceMovePhase.checking => AppBanner(
        tone: AppBannerTone.neutral,
        title: l10n.workspacesMoveLost,
        detail: moveTimedOut
            ? l10n.workspacesMoveLostSlow
            : l10n.workspacesMoveLostDetail,
      ),
      WorkspaceMovePhase.changed => AppBanner(
        tone: AppBannerTone.success,
        title: l10n.workspacesMoveChanged(workspaceShortName(folder, max: 32)),
        detail: l10n.workspacesMoveChangedDetail,
      ),
      WorkspaceMovePhase.unchanged => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.workspacesMoveNotChanged,
        action: action(l10n.workspacesTryAgain, onTryAgain),
      ),
      WorkspaceMovePhase.couldNotConfirm => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.workspacesMoveUnconfirmed,
        detail: l10n.workspacesMoveUnconfirmedDetail(target),
        action: action(l10n.workspacesCheckAgain, onCheckAgain),
      ),
      WorkspaceMovePhase.folderMissing => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.workspacesMoveFolderMissing,
        detail: l10n.workspacesMoveStillRuns(stillIn),
      ),
      WorkspaceMovePhase.chatGone => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.workspacesMoveChatGone,
        detail: l10n.workspacesMoveNothingChanged,
      ),
      WorkspaceMovePhase.profileGone => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.workspacesMoveProfileGone,
        detail: l10n.workspacesMoveNothingChanged,
      ),
    };
  }
}

/// A value with, when there is one, a warning line under it.
class _Value extends StatelessWidget {
  const _Value(this.child, {this.warning});

  final Widget child;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final warning = this.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: metrics.titleSize,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          child: child,
        ),
        if (warning != null)
          GroupedStatusLine(
            icon: AppIcons.warning,
            text: warning,
            color: colors.warning,
            size: metrics.subtitleSize,
            scaleIcon: true,
          ),
      ],
    );
  }
}

/// A label and its value: side by side, or stacked at a large text size, where
/// nothing is cut.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final stacked = isLargeText(context);
    final labelText = ExcludeSemantics(
      child: Text(
        label,
        style: TextStyle(fontSize: metrics.subtitleSize, color: muted),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowPadding,
              vertical: metrics.rowVerticalPadding + 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            labelText,
                            const SizedBox(height: 2),
                            child,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: metrics.titleSize * 5.5,
                              child: labelText,
                            ),
                            Expanded(child: child),
                          ],
                        ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: trailing,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
