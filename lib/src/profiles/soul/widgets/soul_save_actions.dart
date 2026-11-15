import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../tools/widgets/tools_target.dart';
import '../../../widgets/motion_spinner.dart';
import '../../../widgets/settings_scaffold.dart';

/// Whether Save (and Revert) can be pressed: only while the text differs from
/// what the server holds and nothing is running. Both are always drawn and
/// disabled while clean, never hidden.
bool soulCanSave({required bool dirty, required bool busy}) => dirty && !busy;

enum _Part { buttons, revertButton }

/// Save and Revert.
///
/// - Wide windows and the Mac ([SoulSaveActions.new]): Revert (outlined) and
///   Save (filled) side by side, trailing, under the editor; the bar carries
///   no Save there.
/// - A phone: Save is the bar's text action ([SoulSaveActions.barAction],
///   which the page hands to `SettingsScaffold.formAction`), and Revert is a
///   quiet text button in the footer of the editor's card, before the count
///   ([SoulSaveActions.revertButton], handed to `SoulEditor.footerAction`),
///   its label lined up with the text of the field above it.
///
/// Both are enabled by [soulCanSave]. While [busy] (the check read, the PUT
/// or a check runs) Save shows a spinner in place of its label. Every button
/// has the platform's minimum target: 44 pt on iOS, 48 dp on Android, 28 pt on
/// a Mac, set on the button, not by eye. It takes plain values and callbacks.
class SoulSaveActions extends StatelessWidget {
  const SoulSaveActions({
    super.key,
    required this.dirty,
    required this.busy,
    required this.onSave,
    required this.onRevert,
  }) : _part = _Part.buttons;

  /// Only the quiet Revert button, for a phone.
  const SoulSaveActions.revertButton({
    super.key,
    required this.dirty,
    required this.busy,
    required this.onRevert,
  }) : onSave = null,
       _part = _Part.revertButton;

  final bool dirty;
  final bool busy;
  final VoidCallback? onSave;
  final VoidCallback onRevert;
  final _Part _part;

  /// Save as the phone bar's text action; its spinner replaces the label
  /// while [busy].
  static SettingsFormAction barAction(
    BuildContext context, {
    required bool dirty,
    required bool busy,
    required VoidCallback onSave,
  }) => SettingsFormAction(
    label: context.l10n.profilesSoulSave,
    onPressed: soulCanSave(dirty: dirty, busy: busy) ? onSave : null,
    busy: busy,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = soulCanSave(dirty: dirty, busy: busy);
    if (_part == _Part.revertButton) {
      return TextButton(
        onPressed: enabled ? onRevert : null,
        // No inner side padding, so the label starts where the card's text
        // starts; the target still extends past it.
        style: toolsButtonStyle(context).merge(
          const ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
          ),
        ),
        child: Text(l10n.profilesSoulRevert),
      );
    }
    final style = toolsButtonStyle(context);
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: enabled ? onRevert : null,
          style: style,
          child: Text(l10n.profilesSoulRevert),
        ),
        FilledButton(
          onPressed: enabled ? onSave : null,
          style: style,
          child: busy
              ? Semantics(
                  label: l10n.profilesSoulSaving,
                  child: const MotionSpinner(),
                )
              : Text(l10n.profilesSoulSave),
        ),
      ],
    );
  }
}
