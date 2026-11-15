import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/dialog_presentation.dart';

/// Asks whether to leave a memory with an unsaved draft. Answers true only
/// when the user chose to discard the draft. [pending] names a save or delete
/// request that has no answer yet.
Future<bool> showMemoryLeaveConfirm(
  BuildContext context, {
  required bool pending,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (dialog) => MemoryLeaveAlert(
        pending: pending,
        onKeep: () => Navigator.pop(dialog, false),
        onDiscard: () => Navigator.pop(dialog, true),
      ),
    ) ??
    false;

/// Asks before one memory entry is deleted. Answers true only on Delete.
Future<bool> showMemoryDeleteConfirm(BuildContext context) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (dialog) => MemoryDeleteAlert(
        onCancel: () => Navigator.pop(dialog, false),
        onDelete: () => Navigator.pop(dialog, true),
      ),
    ) ??
    false;

/// Asks before [count] waiting changes are all rejected. Answers true only on
/// Reject all.
Future<bool> showMemoryRejectAllConfirm(
  BuildContext context, {
  required int count,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (dialog) => MemoryRejectAllAlert(
        count: count,
        onCancel: () => Navigator.pop(dialog, false),
        onReject: () => Navigator.pop(dialog, true),
      ),
    ) ??
    false;

/// Keep draft is the default and plain text; discarding is destructive text,
/// never filled.
class MemoryLeaveAlert extends StatelessWidget {
  const MemoryLeaveAlert({
    super.key,
    required this.pending,
    required this.onKeep,
    required this.onDiscard,
  });

  final bool pending;
  final VoidCallback onKeep, onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      scrollable: true,
      title: Text(l10n.memoryLeaveTitle),
      content: Text(
        pending
            ? l10n.memoryLeaveMessagePending
            : l10n.memoryLeaveMessageUnsaved,
      ),
      actions: [
        AppDialogAction(
          isDefault: true,
          filledOnMaterial: false,
          onPressed: onKeep,
          child: Text(l10n.memoryLeaveKeepDraft),
        ),
        AppDialogAction(
          isDestructive: true,
          onPressed: onDiscard,
          child: Text(l10n.memoryLeaveDiscard),
        ),
      ],
    );
  }
}

/// Cancel is the default on Apple platforms; Delete is destructive text.
class MemoryDeleteAlert extends StatelessWidget {
  const MemoryDeleteAlert({
    super.key,
    required this.onCancel,
    required this.onDelete,
  });

  final VoidCallback onCancel, onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ConfirmAlert(
      title: l10n.memoryDeleteConfirmTitle,
      message: l10n.memoryDeleteConfirmMessage,
      confirmLabel: l10n.memoryDeleteConfirmAction,
      onCancel: onCancel,
      onConfirm: onDelete,
    );
  }
}

/// Cancel is the default on Apple platforms; Reject all is destructive text.
class MemoryRejectAllAlert extends StatelessWidget {
  const MemoryRejectAllAlert({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onReject,
  });

  final int count;
  final VoidCallback onCancel, onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ConfirmAlert(
      title: l10n.memoryRejectAllTitle,
      message: l10n.memoryRejectAllMessage(count),
      confirmLabel: l10n.memoryRejectAllAction,
      onCancel: onCancel,
      onConfirm: onReject,
    );
  }
}

class _ConfirmAlert extends StatelessWidget {
  const _ConfirmAlert({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title, message, confirmLabel;
  final VoidCallback onCancel, onConfirm;

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    scrollable: true,
    title: Text(title),
    content: Text(message),
    actions: [
      AppDialogAction(
        isDefault: platformChromeOf(context).isApple,
        filledOnMaterial: false,
        onPressed: onCancel,
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      AppDialogAction(
        isDestructive: true,
        onPressed: onConfirm,
        child: Text(confirmLabel),
      ),
    ],
  );
}
