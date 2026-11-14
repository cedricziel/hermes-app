import 'package:flutter/material.dart';

import '../../../theme/platform_chrome.dart';
import '../../../widgets/destructive_tint_button.dart';

/// The frame both restore confirmations share, for use inside
/// `showAdaptiveSheet`: a title, a body that scrolls when the space runs out,
/// an optional line above the buttons and the two buttons. The title and the
/// body scroll together; the line and the buttons stay in view.
///
/// Cancel is the default and takes the first focus. The destructive button is
/// never filled: [DestructiveTintButton] on Apple platforms, red text beside a
/// plain Cancel on Material. At a large text size the buttons stack full
/// width, Cancel first. A null [onConfirm] draws the destructive button
/// disabled.
class RestoreConfirmationLayout extends StatelessWidget {
  const RestoreConfirmationLayout({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.footer,
  });

  final String title;
  final Widget body;
  final Widget? footer;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  /// Past this scaled size of a 14 pt label, the buttons stack.
  static bool stackedFor(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 21;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A long German title would break inside a word at the largest size, so
    // the title stops growing at twice its size; the body keeps scaling.
    final heading = Semantics(
      header: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2,
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final top = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [heading, const SizedBox(height: 12), body],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (constraints.maxHeight.isFinite)
                Flexible(child: SingleChildScrollView(child: top))
              else
                top,
              if (footer != null) ...[const SizedBox(height: 12), footer!],
              const SizedBox(height: 16),
              _Buttons(
                stacked: stackedFor(context),
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: onCancel,
                onConfirm: onConfirm,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.stacked,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool stacked;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final minHeight = switch (chrome) {
      PlatformChrome.material => 48.0,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
    };
    final Widget cancel;
    final Widget confirm;
    if (chrome.isApple) {
      cancel = FilledButton(
        autofocus: true,
        onPressed: onCancel,
        style: FilledButton.styleFrom(
          minimumSize: Size(0, minHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(cancelLabel, textAlign: TextAlign.center),
      );
      confirm = DestructiveTintButton(
        label: confirmLabel,
        onPressed: onConfirm,
      );
    } else {
      final error = Theme.of(context).colorScheme.error;
      cancel = TextButton(
        autofocus: true,
        onPressed: onCancel,
        style: TextButton.styleFrom(
          minimumSize: Size(64, minHeight),
          visualDensity: VisualDensity.standard,
        ),
        child: Text(cancelLabel, textAlign: TextAlign.center),
      );
      confirm = TextButton(
        onPressed: onConfirm,
        style: TextButton.styleFrom(
          foregroundColor: error,
          minimumSize: Size(64, minHeight),
          visualDensity: VisualDensity.standard,
        ),
        child: Text(confirmLabel, textAlign: TextAlign.center),
      );
    }
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cancel, const SizedBox(height: 8), confirm],
      );
    }
    if (!chrome.isApple) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [cancel, confirm],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 12),
          Expanded(child: confirm),
        ],
      ),
    );
  }
}
