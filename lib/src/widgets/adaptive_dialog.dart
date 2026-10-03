import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

/// An alert that is a [CupertinoAlertDialog] on iOS and macOS and a Material
/// [AlertDialog] elsewhere. Build [actions] from [AppDialogAction].
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (!platformChromeOf(context).isApple) {
      return AlertDialog(title: title, content: content, actions: actions);
    }
    // Material fields inside the content still need a Material ancestor.
    return CupertinoAlertDialog(
      title: title,
      content: content == null
          ? null
          : Material(type: MaterialType.transparency, child: content),
      actions: actions,
    );
  }
}

/// A button of an [AppAlertDialog]: a [CupertinoDialogAction] on Apple
/// platforms; elsewhere a [FilledButton] when [isDefault], else a
/// [TextButton].
class AppDialogAction extends StatelessWidget {
  const AppDialogAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isDefault;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    if (platformChromeOf(context).isApple) {
      return CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: isDefault,
        isDestructiveAction: isDestructive,
        child: child,
      );
    }
    return isDefault
        ? FilledButton(onPressed: onPressed, child: child)
        : TextButton(onPressed: onPressed, child: child);
  }
}

/// A text field for a dialog: [CupertinoTextField] on Apple platforms.
class AppDialogTextField extends StatelessWidget {
  const AppDialogTextField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (platformChromeOf(context).isApple) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CupertinoTextField(
          controller: controller,
          autofocus: true,
          placeholder: hint,
          minLines: minLines,
          maxLines: maxLines,
          onSubmitted: onSubmitted,
          clearButtonMode: OverlayVisibilityMode.editing,
        ),
      );
    }
    return TextField(
      controller: controller,
      autofocus: true,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(hintText: hint),
      onSubmitted: onSubmitted,
    );
  }
}

/// Asks [title] (with an optional [message]) and answers true only when the
/// user taps [confirmLabel]. Dismissing or cancelling answers false.
///
/// On Material, [filled] picks a filled over a plain confirm button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool filled = true,
}) async =>
    await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialog) => AppAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          AppDialogAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(cancelLabel),
          ),
          AppDialogAction(
            isDefault: filled,
            isDestructive: destructive,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;
