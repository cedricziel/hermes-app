import 'package:flutter/material.dart';

import '../../tools/widgets/tools_target.dart';
import '../../widgets/motion_spinner.dart';

/// A button of the WhatsApp link screen at the platform's target (44 pt on
/// iOS, 48 dp on Material, 28 pt on a Mac). [PairingButton.filled] is the one
/// button that moves the setup on; [PairingButton.outlined] is Cancel and Back,
/// never filled and never red. While [busy] the button stays, keeps its width
/// and is disabled, with a spinner before its label.
class PairingButton extends StatelessWidget {
  const PairingButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  }) : _filled = true;

  const PairingButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  }) : _filled = false;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool _filled;

  @override
  Widget build(BuildContext context) {
    final style = toolsButtonStyle(context);
    final text = Text(label, textAlign: TextAlign.center);
    final child = busy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MotionSpinner(),
              const SizedBox(width: 8),
              Flexible(child: text),
            ],
          )
        : text;
    final onPressed = busy ? null : this.onPressed;
    return _filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

/// The buttons of one state, primary first. On a handset they stack at full
/// width; on a tablet or a computer they keep their natural width in a row
/// that wraps.
class PairingActions extends StatelessWidget {
  const PairingActions({
    super.key,
    required this.handset,
    required this.children,
    this.alignment = WrapAlignment.start,
  });

  final bool handset;
  final List<Widget> children;

  /// Where the row sits when it is not stacked.
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => handset
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: children,
        )
      : Wrap(
          alignment: alignment,
          spacing: 12,
          runSpacing: 12,
          children: children,
        );
}
