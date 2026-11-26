import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/focus_ring.dart';

/// What the user is told before taking over the screen, with a way not to be
/// asked again. It is the content of a sheet (a bottom sheet on a phone, a
/// dialog on a Mac or a wide window) that the caller shows and dismisses.
///
/// [onConfirm] is told whether the user chose not to be asked again for this
/// account. Without somewhere to remember that ([offerDontAskAgain] false) the
/// switch is left out and the answer is always false.
class TakeoverConfirmation extends StatefulWidget {
  const TakeoverConfirmation({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.offerDontAskAgain = true,
  });

  final VoidCallback onCancel;
  final ValueChanged<bool> onConfirm;
  final bool offerDontAskAgain;

  @override
  State<TakeoverConfirmation> createState() => _TakeoverConfirmationState();
}

class _TakeoverConfirmationState extends State<TakeoverConfirmation> {
  var _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                l10n.botScreenTakeoverTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          paragraph(l10n.botScreenTakeoverStopsAgent),
          paragraph(l10n.botScreenTakeoverTypesToServer),
          paragraph(l10n.botScreenTakeoverHidesPreviews),
          if (widget.offerDontAskAgain)
            FocusRing(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.botScreenTakeoverDontAskAgain),
                value: _dontAskAgain,
                onChanged: (value) => setState(() => _dontAskAgain = value),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(l10n.botScreenTakeoverCancel),
              ),
              FilledButton(
                onPressed: () => widget.onConfirm(_dontAskAgain),
                child: Text(l10n.botScreenTakeoverConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
