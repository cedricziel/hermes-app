import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/secret_field_row.dart';
import 'tools_load_state.dart';
import 'tools_switch.dart';
import 'tools_target.dart';

/// Where the key form stands. The typed values are the caller's: it clears
/// each field's controller after [saved] and [checking], and keeps them after
/// [failed].
enum ToolsetKeyFormPhase {
  idle,
  saving,

  /// The last save worked and the fields were cleared.
  saved,

  /// The save failed; the typed values are still in their fields, hidden.
  failed,

  /// The answer to the save was lost; Hermes is being asked again.
  checking,

  /// Hermes could not be asked again in time.
  unconfirmed,

  /// Asked again, the key is not set; the user has to paste it again.
  notSaved,
}

/// One key a provider needs.
class ToolsetKeyField {
  const ToolsetKeyField({
    required this.label,
    required this.controller,
    this.isSet = false,
    this.replacing = false,
    this.hasLink = false,
  });

  /// Hermes' own label for the key, such as "Firecrawl API key".
  final String label;
  final TextEditingController controller;

  /// Hermes has a value. It is never shown; the row says "Already set".
  final bool isSet;

  /// The user asked to replace a value that is set, so the field shows.
  final bool replacing;

  /// There is a page where the user can get the key.
  final bool hasLink;

  bool get editable => !isSet || replacing;
}

/// The keys a provider needs, as the Tools screens show them: a section
/// "Key for provider" with the app-wide [SecretFieldRow] for each key to
/// type or "Already set" with Replace for one that is, the helper, "Get a
/// key", Save, which is the one filled button of the screen, and the quiet
/// line about removing a key.
///
/// It takes plain values and a [TextEditingController] per field, and holds
/// no secret of its own. Raise [hideSignal] after a failed save so a shown
/// key hides again; the field itself hides a key when the app leaves the
/// foreground and when a save starts.
class ToolsetKeyForm extends StatelessWidget {
  const ToolsetKeyForm({
    super.key,
    required this.provider,
    required this.profile,
    required this.fields,
    required this.phase,
    required this.hideSignal,
    required this.onSave,
    required this.onReplace,
    required this.onGetKey,
    this.onChanged,
    this.onTryAgain,
  });

  final String provider;
  final String profile;
  final List<ToolsetKeyField> fields;
  final ToolsetKeyFormPhase phase;
  final int hideSignal;

  /// Null while there is nothing typed to save.
  final VoidCallback? onSave;
  final ValueChanged<ToolsetKeyField> onReplace;
  final ValueChanged<ToolsetKeyField> onGetKey;

  /// Called when a field's text changes, so Save can follow what is typed.
  final VoidCallback? onChanged;

  /// With [ToolsetKeyFormPhase.unconfirmed]: reads Hermes again. Given where
  /// nothing pulls to refresh (a Mac, a wide window); then the line says "Try
  /// again" instead of "Pull to refresh" and carries the button.
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.hermesColors;
    final metrics = GroupedMetrics.of(context);
    final busy =
        phase == ToolsetKeyFormPhase.saving ||
        phase == ToolsetKeyFormPhase.checking;
    final anyEditable = fields.any((field) => field.editable);

    Widget fieldRow(ToolsetKeyField field) {
      if (!field.editable) {
        return _AlreadySetRow(field: field, onReplace: () => onReplace(field));
      }
      return SecretFieldRow(
        label: field.label,
        controller: field.controller,
        busy: busy,
        enabled: !busy,
        hideSignal: hideSignal,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
      );
    }

    // The failure is a line under the section rather than the field's own
    // error text, which an Apple row cuts off at one line.
    final status = switch (phase) {
      ToolsetKeyFormPhase.failed => (
        AppIcons.error,
        Theme.of(context).colorScheme.error,
        l10n.toolsKeyFailed,
      ),
      ToolsetKeyFormPhase.unconfirmed => (
        AppIcons.questionCircleFilled,
        colors.warning,
        onTryAgain == null
            ? l10n.toolsKeyUnconfirmed
            : l10n.toolsKeyUnconfirmedRetry,
      ),
      ToolsetKeyFormPhase.notSaved => (
        AppIcons.warningFilled,
        colors.warning,
        l10n.toolsKeyNotSaved,
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phase == ToolsetKeyFormPhase.saved)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppBanner(
              tone: AppBannerTone.success,
              title: l10n.toolsKeySaved,
              detail: l10n.toolsKeySavedDetail,
            ),
          ),
        GroupedSection(
          header: l10n.toolsKeyHeader(provider),
          footer: l10n.toolsKeyHelper(profile),
          children: [for (final field in fields) fieldRow(field)],
        ),
        for (final field in fields)
          if (field.hasLink)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: metrics.rowPadding - 8,
                  top: 4,
                ),
                child: _GetKeyLink(
                  label: field.label,
                  onPressed: () => onGetKey(field),
                ),
              ),
            ),
        if (status != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              8,
              metrics.rowPadding,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              container: true,
              label: status.$3,
              child: ExcludeSemantics(
                child: GroupedStatusLine(
                  icon: status.$1,
                  text: status.$3,
                  color: status.$2,
                  size: metrics.subtitleSize,
                ),
              ),
            ),
          ),
        if (phase == ToolsetKeyFormPhase.unconfirmed && onTryAgain != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: metrics.rowPadding - 8,
              ),
              child: TextButton(
                onPressed: onTryAgain,
                style: toolsButtonStyle(context),
                child: Text(l10n.toolsTryAgain),
              ),
            ),
          ),
        if (anyEditable)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: phase == ToolsetKeyFormPhase.checking
                ? ToolsLoadingRow(l10n.toolsKeyChecking)
                : _SaveButton(
                    saving: phase == ToolsetKeyFormPhase.saving,
                    onPressed: onSave,
                  ),
          ),
        GroupedFooter(l10n.toolsKeyRemoveHint),
      ],
    );
  }
}

/// A key that is set: its label, "Already set" with a check, and an outlined
/// Replace. The value is never shown.
class _AlreadySetRow extends StatelessWidget {
  const _AlreadySetRow({required this.field, required this.onReplace});

  final ToolsetKeyField field;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final success = context.hermesColors.success;
    return GroupedRow(
      title: field.label,
      titleMaxLines: null,
      details: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              AppIcon(
                AppIcons.checkCircleFilled,
                size: MediaQuery.textScalerOf(context)
                    .scale(metrics.subtitleSize + 2),
                color: success,
              ),
              Flexible(
                child: Text(
                  l10n.toolsKeyAlreadySet,
                  style: TextStyle(
                    fontSize: metrics.subtitleSize,
                    color: success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      separateTrailing: true,
      trailingBelow: toolsLargeText(context),
      trailing: Semantics(
        button: true,
        label: l10n.toolsKeyReplaceNamed(field.label),
        onTap: onReplace,
        excludeSemantics: true,
        child: OutlinedButton(
          onPressed: onReplace,
          style: toolsButtonStyle(context),
          child: Text(l10n.toolsKeyReplace),
        ),
      ),
    );
  }
}

/// "Get a key": the link colour and an external-link icon, at the platform's
/// target height. It only calls back; the screen opens the page.
class _GetKeyLink extends StatelessWidget {
  const _GetKeyLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final link = context.hermesColors.link;
    return Semantics(
      button: true,
      link: true,
      // The link names its key, so several of them are told apart.
      label: l10n.toolsKeyGetNamed(label),
      onTap: onPressed,
      excludeSemantics: true,
      child: TextButton.icon(
        onPressed: onPressed,
        style: toolsButtonStyle(context)
            .copyWith(foregroundColor: WidgetStatePropertyAll(link)),
        icon: AppIcon(AppIcons.openExternal, size: 18, color: link),
        iconAlignment: IconAlignment.end,
        label: Text(l10n.toolsKeyGet),
      ),
    );
  }
}

/// The full-width filled Save. While saving it keeps its place, shows a
/// spinner (a still hourglass with reduced motion) and cannot be pressed.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The disabled button's own colours stay, so the spinner (the text
    // colour) stays visible on them.
    return Semantics(
      liveRegion: saving,
      child: FilledButton(
        onPressed: saving ? null : onPressed,
        style: toolsButtonStyle(context, wide: true),
        child: saving
            ? Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  const ToolsSpinner(),
                  Flexible(child: Text(l10n.toolsKeySaving)),
                ],
              )
            : Text(l10n.toolsKeySave),
      ),
    );
  }
}
