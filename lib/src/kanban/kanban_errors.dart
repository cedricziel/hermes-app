import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../telemetry/report_bug.dart';
import '../theme/platform_chrome.dart';
import '../widgets/route_dismissal.dart';
import 'kanban_repository.dart';

/// Runs a write, and tells the user why when the plugin refuses it. Returns
/// whether it went through.
Future<bool> runKanbanAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on KanbanException catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  } on Object catch (e, stack) {
    reportBug(e, stack, 'a Kanban action');
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    }
  }
  return false;
}

/// Shows a Kanban dialog that has its own actions, through [showAppDialog].
///
/// A [textEntry] dialog makes the macOS barrier inert, so a stray click does
/// not throw away typed text. An inert barrier (that one, and iOS's own) turns
/// Esc off with it, so Esc is bound here on both Apple platforms and closes
/// the route; Material keeps what it had. Esc only reaches the binding from a
/// focus inside the dialog, so a scope of its own sits under it: focus that
/// leaves a field (a click on the title or a row) lands there, not on the
/// route's scope above the binding. It takes focus first unless the dialog has
/// an autofocus field ([autofocusField]).
Future<T?> showKanbanDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool textEntry = false,
  bool autofocusField = false,
}) {
  final chrome = platformChromeOf(context);
  return showAppDialog<T>(
    context: context,
    barrierDismissible: textEntry && chrome == PlatformChrome.macos
        ? false
        : null,
    builder: (dialog) {
      if (chrome == PlatformChrome.material) return builder(dialog);
      final content = Builder(builder: builder);
      return Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) => dismissRoute(dialog),
          ),
        },
        child: FocusScope(autofocus: !autofocusField, child: content),
      );
    },
  );
}

/// Asks for a line of text; null when cancelled.
Future<String?> askKanbanText(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  String confirm = 'OK',
  bool multiline = false,
}) => showAppDialog<String>(
  context: context,
  // A stray click on macOS must not throw away typed text; Esc and Cancel close.
  barrierDismissible: platformChromeOf(context) == PlatformChrome.macos
      ? false
      : null,
  builder: (_) => _TextDialog(
    title: title,
    hint: hint,
    initial: initial,
    confirm: confirm,
    multiline: multiline,
  ),
);

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.confirm,
    required this.multiline,
    this.hint,
    this.initial,
  });

  final String title;
  final String? hint;
  final String? initial;
  final String confirm;
  final bool multiline;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Actions(
    // The macOS barrier is inert here, which also turns Esc off; the other
    // platforms keep what they had.
    actions: platformChromeOf(context) == PlatformChrome.macos
        ? {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) => dismissRoute(context),
            ),
          }
        : const {},
    child: AppAlertDialog(
      title: Text(widget.title),
      content: AppDialogTextField(
        controller: _controller,
        hint: widget.hint,
        minLines: widget.multiline ? 3 : 1,
        maxLines: widget.multiline ? 6 : 1,
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AppDialogAction(
          isDefault: true,
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    ),
  );
}

Future<bool> confirmKanban(
  BuildContext context, {
  required String title,
  required String confirm,
}) => showConfirmDialog(context, title: title, confirmLabel: confirm);
