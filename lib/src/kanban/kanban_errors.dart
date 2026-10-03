import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

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
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on Object catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Something went wrong. Try again.')),
    );
  }
  return false;
}

/// Asks for a line of text; null when cancelled.
Future<String?> askKanbanText(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  String confirm = 'OK',
  bool multiline = false,
}) => showAdaptiveDialog<String>(
  context: context,
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
  Widget build(BuildContext context) => AppAlertDialog(
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
  );
}

Future<bool> confirmKanban(
  BuildContext context, {
  required String title,
  required String confirm,
}) => showConfirmDialog(context, title: title, confirmLabel: confirm);
