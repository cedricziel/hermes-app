import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../tools/widgets/tools_target.dart';
import '../../../widgets/motion_spinner.dart';
import '../../../widgets/settings_scaffold.dart';
import 'soul_line_metrics.dart';

/// Whether Save (and Revert) can be pressed: only while the text differs from
/// what the server holds and nothing is running. Both are always drawn and
/// disabled while clean, never hidden.
bool soulCanSave({required bool dirty, required bool busy}) => dirty && !busy;

enum _Part { buttons, revertRow }

/// Save and Revert.
///
/// - Wide windows and the Mac ([SoulSaveActions.new]): Revert (outlined) and
///   Save (filled) side by side, trailing, under the editor; the bar carries
///   no Save there.
/// - A phone: Save is the bar's text action ([SoulSaveActions.barAction],
///   which the page hands to `SettingsScaffold.formAction`), and Revert is a
///   quiet text button on its own row under the editor
///   ([SoulSaveActions.revertRow]), its label lined up with the text of the
///   note and status lines above it (after their icon, see
///   [SoulLineMetrics.textInset]).
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
  const SoulSaveActions.revertRow({
    super.key,
    required this.dirty,
    required this.busy,
    required this.onRevert,
  }) : onSave = null,
       _part = _Part.revertRow;

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
    if (_part == _Part.revertRow) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: SoulLineMetrics.textInset(context),
          ),
          child: TextButton(
            onPressed: enabled ? onRevert : null,
            // No inner side padding, so the label starts where the note and
            // status text above it start (the row's inset is the icon, the gap
            // and the lines' own padding); the target still extends past it.
            style: toolsButtonStyle(context).merge(
              const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 8),
                ),
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            child: Text(l10n.profilesSoulRevert),
          ),
        ),
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
