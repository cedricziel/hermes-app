import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// What the user is told before taking over the screen, with a way not to be
/// asked again. It is the content of a sheet (a bottom sheet on a phone, a
/// dialog on a Mac or a wide window) that the caller shows and dismisses.
///
/// [onConfirm] is told whether the user chose not to be asked again for this
/// account.
class TakeoverConfirmation extends StatefulWidget {
  const TakeoverConfirmation({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final ValueChanged<bool> onConfirm;

  @override
  State<TakeoverConfirmation> createState() => _TakeoverConfirmationState();
}

class _TakeoverConfirmationState extends State<TakeoverConfirmation> {
  var _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.hermesColors.subtleText;
    Widget paragraph(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Take over the screen?',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          paragraph(
            'Hermes stops using the screen until you hand it back. The step '
            'it is on may end, and you may need to tell it to continue.',
          ),
          paragraph('What you type goes to the server’s desktop.'),
          paragraph(
            'This app’s previews and your viewers on other devices hide '
            'the picture meanwhile. Hermes Desktop’s live viewers may '
            'still see it.',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text("Don't ask again"),
            value: _dontAskAgain,
            onChanged: (value) => setState(() => _dontAskAgain = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => widget.onConfirm(_dontAskAgain),
                child: const Text('Take over'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
