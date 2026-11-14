import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/adaptive_dialog.dart';
import 'workspace_widget_support.dart';

/// The text of the confirmation: what will happen, then a blank line and the
/// path with "on your server".
String changeFolderConfirmationMessage(
  AppLocalizations l10n, {
  required String folderName,
  required String path,
}) =>
    '${l10n.workspacesConfirmBody(workspaceShortName(folderName, max: 40))}'
    '\n\n$path · ${l10n.workspacesOnYourServer}';

/// "Change the folder for this chat?": the confirmation before a chat is
/// moved to another folder. It is [showConfirmDialog]: an alert on Apple
/// platforms, a dialog on Android.
///
/// Cancel is the default (bold on Apple platforms) and "Change folder" is a
/// plain action, never filled and never red: nothing is deleted, but the agent
/// will act somewhere else. On Android both are text buttons, Cancel first.
/// Resolves true only when the person confirms.
Future<bool> showChangeFolderConfirmation(
  BuildContext context, {
  required String folderName,
  required String path,
}) {
  final l10n = context.l10n;
  return showConfirmDialog(
    context,
    title: l10n.workspacesConfirmTitle,
    message: changeFolderConfirmationMessage(
      l10n,
      folderName: folderName,
      path: path,
    ),
    confirmLabel: l10n.workspacesConfirmAction,
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    filled: false,
    cancelIsDefault: true,
  );
}
