import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/route_dismissal.dart';

/// The "Rename chat" dialog of a thread's menu. Pops the trimmed new title on
/// Save (never an empty one) and nothing on Cancel; [initial] fills the field.
class ThreadRenameDialog extends StatefulWidget {
  const ThreadRenameDialog({super.key, required this.initial});

  final String initial;

  @override
  State<ThreadRenameDialog> createState() => _ThreadRenameDialogState();
}

class _ThreadRenameDialogState extends State<ThreadRenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dialog = AppAlertDialog(
      title: Text(l10n.chatWidgetsThreadMenuRenameTitle),
      content: AppDialogTextField(
        controller: _controller,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.chatWidgetsThreadMenuCancel),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => AppDialogAction(
            isDefault: true,
            onPressed: _controller.text.trim().isEmpty ? null : _save,
            child: Text(l10n.chatWidgetsThreadMenuSave),
          ),
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
