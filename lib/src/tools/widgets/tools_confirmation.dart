import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/dialog_presentation.dart';
import '../toolset_copy.dart';

/// The question asked before a toolset or a setup step changes something on
/// the server: the platform alert with Cancel first and the default, and the
/// confirming action plain. Nothing here is deleted, so nothing is red or
/// filled. On Android the two are text buttons, Cancel first.
///
/// It takes the question as plain text and answers through the navigator:
/// true only for the confirming action.
class ToolsetConfirmDialog extends StatelessWidget {
  const ToolsetConfirmDialog({super.key, required this.question});

  final ToolsetQuestion question;

  @override
  Widget build(BuildContext context) {
    final apple = platformChromeOf(context).isApple;
    return AppAlertDialog(
      title: Text(question.title),
      // A Material dialog does not scroll its content by itself, so a long
      // body at the largest text size would be cut.
      content: apple
          ? Text(question.body)
          : SingleChildScrollView(child: Text(question.body)),
      actions: [
        AppDialogAction(
          // Apple marks the default action in bold; Material would fill it.
          isDefault: apple,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        AppDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(question.confirmLabel),
        ),
      ],
    );
  }
}

/// Asks [question] and answers true only when the user confirms; cancelling
/// and dismissing answer false.
Future<bool> showToolsetConfirmation(
  BuildContext context,
  ToolsetQuestion question,
) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (_) => ToolsetConfirmDialog(question: question),
    ) ??
    false;
