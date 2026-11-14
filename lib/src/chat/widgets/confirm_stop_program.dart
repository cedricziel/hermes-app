import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/adaptive_dialog.dart';

/// The longest command the confirmation's message shows, in characters.
const kConfirmCommandChars = 80;

/// The command cut to one line for the confirmation's message.
String confirmCommandLine(String command) {
  final line = command.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = line.runes.toList();
  if (runes.length <= kConfirmCommandChars) return line;
  return '${String.fromCharCodes(runes.take(kConfirmCommandChars)).trimRight()}…';
}

/// Asks whether to stop the program running [command]. True only when the
/// user confirmed; Cancel is the default. The caller binds the answer to the
/// program it asked about.
Future<bool> confirmStopProgram(
  BuildContext context, {
  required String command,
}) {
  final l10n = context.l10n;
  return showDestructiveConfirm(
    context,
    title: l10n.chatWidgetsProgramConfirmTitle,
    message: l10n.chatWidgetsProgramConfirmMessage(confirmCommandLine(command)),
    confirmLabel: l10n.chatWidgetsProgramStopButton,
    cancelLabel: l10n.chatWidgetsProgramConfirmCancel,
  );
}
