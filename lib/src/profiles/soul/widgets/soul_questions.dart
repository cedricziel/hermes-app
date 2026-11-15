import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../widgets/adaptive_dialog.dart';

/// The save question, asked on every save because saving replaces the whole
/// file: "Replace the personality of NAME?". Cancel is first and the
/// default (bold on Apple platforms); Replace is plain, never filled and never
/// red. On Android two text buttons, Cancel first. [empty] says Hermes will
/// use its default personality; [pendingSaveNote] adds that an earlier save
/// may still be pending. Answers true only for Replace.
Future<bool> askReplaceSoul(
  BuildContext context, {
  required String profile,
  bool empty = false,
  bool pendingSaveNote = false,
}) {
  final l10n = context.l10n;
  final body = empty
      ? l10n.profilesSoulQuestionBodyEmpty
      : l10n.profilesSoulQuestionBody;
  return showConfirmDialog(
    context,
    title: l10n.profilesSoulQuestionTitle(profile),
    message: pendingSaveNote
        ? '$body ${l10n.profilesSoulQuestionPendingNote}'
        : body,
    confirmLabel: l10n.profilesSoulQuestionReplace,
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    filled: false,
    cancelIsDefault: true,
  );
}

/// The discard question, asked when leaving the page, on Revert and on closing
/// the window with unsaved edits: "Discard changes?". Keep editing is first
/// and the default; Discard is plain, not red and not filled (the text is the
/// user's own and nothing is lost on the server). Answers true only for
/// Discard.
Future<bool> askDiscardSoul(BuildContext context, {required String profile}) {
  final l10n = context.l10n;
  return showConfirmDialog(
    context,
    title: l10n.profilesSoulDiscardTitle,
    message: l10n.profilesSoulDiscardBody(profile),
    confirmLabel: l10n.profilesSoulDiscard,
    cancelLabel: l10n.profilesSoulKeepEditing,
    filled: false,
    cancelIsDefault: true,
  );
}
