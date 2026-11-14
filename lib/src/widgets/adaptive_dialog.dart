import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

import 'dialog_presentation.dart';

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
    this.filledOnMaterial = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isDefault;
  final bool isDestructive;

  /// Whether the default action is a filled button on Material. A
  /// confirmation of a destructive action keeps both buttons plain text.
  final bool filledOnMaterial;

  @override
  Widget build(BuildContext context) {
    if (platformChromeOf(context) == PlatformChrome.macos) {
      return _MacDialogAction(
        onPressed: onPressed,
        builder: (activate) => CupertinoDialogAction(
          onPressed: activate,
          isDefaultAction: isDefault,
          isDestructiveAction: isDestructive,
          child: child,
        ),
      );
    }
    if (platformChromeOf(context).isApple) {
      return CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: isDefault,
        isDestructiveAction: isDestructive,
        child: child,
      );
    }
    if (isDefault && filledOnMaterial) {
      return FilledButton(onPressed: onPressed, child: child);
    }
    return TextButton(
      onPressed: onPressed,
      style: isDestructive
          ? TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            )
          : null,
      child: child,
    );
  }
}

class _MacDialogAction extends StatefulWidget {
  const _MacDialogAction({required this.onPressed, required this.builder});
  final VoidCallback? onPressed;
  final Widget Function(VoidCallback? activate) builder;

  @override
  State<_MacDialogAction> createState() => _MacDialogActionState();
}

class _MacDialogActionState extends State<_MacDialogAction> {
  bool _highlight = false;

  Object? _activate(Intent intent) {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return null;
    widget.onPressed?.call();
    return null;
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.onPressed != null,
    onShowFocusHighlight: (value) => setState(() => _highlight = value),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
      ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
        onInvoke: _activate,
      ),
    },
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: _highlight
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: widget.builder(
        widget.onPressed == null
            ? null
            : () => _activate(const ActivateIntent()),
      ),
    ),
  );
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
    await showAppDialog<bool>(
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

/// Asks whether to go through with a destructive action: Cancel is the
/// default (bold on Apple platforms, Return on the Mac) and [confirmLabel] is
/// the destructive button, red, never filled. On Material both are plain text
/// buttons, Cancel first. Answers true only when the user confirmed.
Future<bool> showDestructiveConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  ValueListenable<bool>? dismissWhen,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (dialog) => _DismissWhen(
        when: dismissWhen,
        child: AppAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            AppDialogAction(
              isDefault: true,
              filledOnMaterial: false,
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(cancelLabel),
            ),
            AppDialogAction(
              isDestructive: true,
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ) ??
    false;

/// Closes the dialog it is in, answering false, once [when] turns true: the
/// thing the dialog asks about is gone.
class _DismissWhen extends StatefulWidget {
  const _DismissWhen({required this.when, required this.child});

  final ValueListenable<bool>? when;
  final Widget child;

  @override
  State<_DismissWhen> createState() => _DismissWhenState();
}

class _DismissWhenState extends State<_DismissWhen> {
  @override
  void initState() {
    super.initState();
    widget.when?.addListener(_check);
  }

  void _check() {
    if (widget.when?.value != true || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    widget.when?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
