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
      // Title and body scroll as one region, the actions stay in view.
      scrollable: true,
      title: Text(question.title),
      content: Text(question.body),
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
/// and dismissing answer false. [onRoute] receives the dialog's route, so a
/// caller can take the question down itself.
Future<bool> showToolsetConfirmation(
  BuildContext context,
  ToolsetQuestion question, {
  void Function(Route<dynamic> route)? onRoute,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (dialog) {
        final route = ModalRoute.of(dialog);
        if (route != null) onRoute?.call(route);
        return ToolsetConfirmDialog(question: question);
      },
    ) ??
    false;
