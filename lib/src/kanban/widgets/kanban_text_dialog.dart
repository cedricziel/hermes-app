import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/route_dismissal.dart';

class KanbanTextDialog extends StatefulWidget {
  const KanbanTextDialog({
    super.key,
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
  State<KanbanTextDialog> createState() => _KanbanTextDialogState();
}

class _KanbanTextDialogState extends State<KanbanTextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialog = AppAlertDialog(
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
          child: Text(context.l10n.widgetsCancel),
        ),
        AppDialogAction(
          isDefault: true,
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
    // The macOS barrier is inert here, which also turns Esc off; the other
    // platforms keep what they had. The field autofocuses.
    return platformChromeOf(context) == PlatformChrome.macos
        ? DismissOnEscape(child: dialog)
        : dialog;
  }
}
