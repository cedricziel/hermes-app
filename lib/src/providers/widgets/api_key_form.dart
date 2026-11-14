import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/secret_field_row.dart';
import '../../widgets/settings_scaffold.dart';
import 'provider_form_models.dart';
import 'provider_form_parts.dart';
import 'provider_row_actions.dart';

/// The bar title of the form: "Connect &lt;provider&gt;", or "Replace key".
String apiKeyFormTitle(AppLocalizations l10n, ApiKeyFormData data) =>
    data.replacing
    ? l10n.providersKeyTitleReplace
    : l10n.providersKeyTitle(data.providerName);

/// The bar's Save, or null while the form hides it (after a rejection or a
/// provider error, so "Edit key" or "Save anyway" is the one primary action).
/// Save is a spinner while the key is checked or saved, and disabled until
/// the field holds something. The screen puts it in its [SettingsScaffold].
SettingsFormAction? apiKeyFormAction(
  AppLocalizations l10n,
  ApiKeyFormData data, {
  required bool hasText,
  VoidCallback? onSave,
}) {
  if (!data.saveVisible) return null;
  return SettingsFormAction(
    label: l10n.providersFormSave,
    busy: data.busy,
    onPressed: hasText ? onSave : null,
  );
}

/// The body of the form that takes an API key, from a plain [ApiKeyFormData]:
/// one obscured field (the shared [SecretFieldRow]), a note, the link to get
/// a key, and, after a rejection or a provider error, the buttons that make
/// one action primary.
///
/// The secret field rule applies (`docs/architecture/settings-screens.md`):
/// the key is hidden while a check or save runs and after a failed save,
/// stays in the field through a plain failure, and is cleared here when the
/// answer to a save was lost. The screen owns [controller], clears it when
/// App Lock locks and when the form closes, and never keeps its text; this
/// widget never persists or restores anything.
class ApiKeyForm extends StatefulWidget {
  const ApiKeyForm({
    super.key,
    required this.data,
    required this.controller,
    this.focusRequest = 0,
    this.initiallyShown = false,
    this.onChanged,
    this.onSave,
    this.onSaveAnyway,
    this.onTryAgain,
    this.onEditKey,
    this.onOpenKeyLink,
    this.onUseAccount,
  });

  final ApiKeyFormData data;
  final TextEditingController controller;

  /// Raised by the screen for each "Edit key"; moves focus into the field.
  final int focusRequest;

  /// Only the catalog sets it, to draw a shown key.
  final bool initiallyShown;

  /// The text changed: a rejection or an error gives way to editing.
  final ValueChanged<String>? onChanged;

  /// Save, Save anyway and Try again hand the typed text to the screen.
  final ValueChanged<String>? onSave;
  final ValueChanged<String>? onSaveAnyway;
  final ValueChanged<String>? onTryAgain;
  final VoidCallback? onEditKey;
  final VoidCallback? onOpenKeyLink;
  final VoidCallback? onUseAccount;

  @override
  State<ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends State<ApiKeyForm> {
  final _focus = FocusNode();
  var _hideSignal = 0;

  @override
  void didUpdateWidget(ApiKeyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.data.phase;
    final now = widget.data.phase;
    if (was != now) {
      final failed =
          now == ApiKeyPhase.rejected ||
          now == ApiKeyPhase.providerError ||
          now == ApiKeyPhase.refused ||
          now == ApiKeyPhase.unknown;
      // After a failed save a shown key is hidden again; the text stays.
      if (failed) _hideSignal++;
      // The answer was lost: the key may be saved already, so the field is
      // emptied and the person pastes it again.
      if (now == ApiKeyPhase.unknown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.data.phase == ApiKeyPhase.unknown) {
            widget.controller.clear();
          }
        });
      }
    }
    if (widget.focusRequest != oldWidget.focusRequest) _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String get _text => widget.controller.text;

  void _editKey() {
    _focus.requestFocus();
    widget.onEditKey?.call();
  }

  /// Return in the field does what the primary button does.
  void _submit() {
    switch (widget.data.primaryAction(hasText: _text.isNotEmpty)) {
      case ApiKeyAction.save:
        widget.onSave?.call(_text);
      case ApiKeyAction.editKey:
        _editKey();
      case ApiKeyAction.saveAnyway:
        widget.onSaveAnyway?.call(_text);
      case null:
        break;
    }
  }

  String? _problem(AppLocalizations l10n) {
    final data = widget.data;
    switch (data.phase) {
      case ApiKeyPhase.editing:
        return data.emptyKey ? l10n.providersKeyEmpty : null;
      case ApiKeyPhase.rejected:
        return data.message ?? l10n.providersKeyRejectedFallback;
      case ApiKeyPhase.refused:
        if (data.notAccepted) return l10n.providersNotAccepted;
        return data.message ?? l10n.providersKeyRefusedFallback;
      case ApiKeyPhase.checking ||
          ApiKeyPhase.saving ||
          ApiKeyPhase.providerError ||
          ApiKeyPhase.unknown:
        return null;
    }
  }

  Widget _banner(Widget banner) =>
      Padding(padding: const EdgeInsets.only(top: 12), child: banner);

  Widget _buttons(AppLocalizations l10n) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final hasText = _text.isNotEmpty;
      final data = widget.data;
      final rejected = data.phase == ApiKeyPhase.rejected;
      return ProviderActionStack(
        buttons: (full) => rejected
            ? [
                ProviderRowButton(
                  label: l10n.providersKeyEditKey,
                  filled: true,
                  fullWidth: full,
                  autofocus: true,
                  onPressed: _editKey,
                ),
                ProviderRowButton(
                  label: l10n.providersKeySaveAnyway,
                  outlined: true,
                  fullWidth: full,
                  onPressed: hasText
                      ? () => widget.onSaveAnyway?.call(_text)
                      : null,
                ),
              ]
            : [
                ProviderRowButton(
                  label: l10n.providersKeySaveAnyway,
                  filled: true,
                  fullWidth: full,
                  onPressed: hasText
                      ? () => widget.onSaveAnyway?.call(_text)
                      : null,
                ),
                ProviderRowButton(
                  label: l10n.providersTryAgain,
                  outlined: true,
                  fullWidth: full,
                  onPressed: hasText
                      ? () => widget.onTryAgain?.call(_text)
                      : null,
                ),
              ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = widget.data;
    final metrics = GroupedMetrics.of(context);
    final problem = _problem(l10n);
    return GroupedListView(
      children: [
        if (data.phase == ApiKeyPhase.unknown)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersKeyUnknownTitle,
              detail: l10n.providersKeyUnknownDetail,
            ),
          ),
        if (data.phase == ApiKeyPhase.providerError)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersKeyProviderErrorTitle(data.providerName),
              detail: data.message ?? l10n.providersKeyProviderErrorFallback,
            ),
          ),
        GroupedSection(
          children: [
            SecretFieldRow(
              label: l10n.providersKeyLabel,
              hint: l10n.providersKeyHint,
              controller: widget.controller,
              focusNode: _focus,
              enabled: !data.busy,
              busy: data.busy,
              hideSignal: _hideSignal,
              initiallyShown: widget.initiallyShown,
              onChanged: widget.onChanged,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        if (problem != null) ProviderFieldProblem(problem),
        if (data.busy)
          ProviderStatusLine(
            data.phase == ApiKeyPhase.checking
                ? l10n.providersKeyChecking
                : l10n.providersSaving,
          ),
        GroupedFooter(l10n.providersKeyHelper(data.profile)),
        if (data.offersKeyLink)
          GroupedSection(
            children: [
              GroupedRow(
                title: l10n.providersKeyGetLink(data.providerName),
                titleMaxLines: null,
                chevron: false,
                trailing: AppIcon(
                  AppIcons.openExternal,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: data.busy ? null : widget.onOpenKeyLink,
              ),
            ],
          ),
        if (data.offersSaveAnyway) _buttons(l10n),
        if (data.offersAccount && !data.busy)
          Padding(
            padding: EdgeInsets.only(top: metrics.sectionGap),
            child: Center(
              child: ProviderRowButton(
                label: l10n.providersKeyUseAccount(data.providerName),
                onPressed: widget.onUseAccount,
              ),
            ),
          ),
      ],
    );
  }
}
