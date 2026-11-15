import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/adaptive_dialog.dart';

/// The question before the WhatsApp setup is saved: "Save and restart?".
/// Cancel is first and the default (bold on Apple platforms; the helper binds
/// no key to either button), "Save and restart" is plain, never filled and
/// never red, and on Android the two are text buttons, Cancel first. A long
/// label (German) wraps, and the Apple alert stacks its buttons when two do not
/// fit side by side. Answers true only for "Save and restart"; dismissing
/// answers false.
Future<bool> askFinishWhatsApp(BuildContext context) {
  final l10n = context.l10n;
  return showConfirmDialog(
    context,
    title: l10n.messagingWhatsappFinishQuestionTitle,
    message: l10n.messagingWhatsappFinishQuestionBody,
    confirmLabel: l10n.messagingWhatsappFinishQuestionConfirm,
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    filled: false,
    cancelIsDefault: true,
  );
}
