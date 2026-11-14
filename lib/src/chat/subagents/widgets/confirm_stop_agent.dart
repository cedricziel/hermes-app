import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../l10n/l10n.dart';
import '../../../widgets/adaptive_dialog.dart';

/// The longest goal the confirmation's message shows, in characters. The
/// message names the agent on one line, so a long goal is cut.
const kConfirmGoalChars = 80;

/// The goal cut to one line for the confirmation's message.
String confirmGoalLine(String goal) {
  final line = goal.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = line.runes.toList();
  if (runes.length <= kConfirmGoalChars) return line;
  return '${String.fromCharCodes(runes.take(kConfirmGoalChars)).trimRight()}…';
}

/// Asks whether to stop the agent named by [goal]. True only when the user
/// confirmed; Cancel is the default, "Stop agent" is the destructive button
/// (a system alert on Apple platforms, two text buttons on Material, Cancel
/// first). The caller binds the answer to the agent it asked about.
Future<bool> confirmStopAgent(
  BuildContext context, {
  required String goal,
  ValueListenable<bool>? dismissWhen,
}) {
  final l10n = context.l10n;
  return showDestructiveConfirm(
    context,
    title: l10n.chatSubagentsConfirmTitle,
    message: l10n.chatSubagentsConfirmMessage(confirmGoalLine(goal)),
    confirmLabel: l10n.chatSubagentsStopButton,
    cancelLabel: l10n.chatSubagentsConfirmCancel,
    dismissWhen: dismissWhen,
  );
}
