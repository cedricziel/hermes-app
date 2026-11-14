import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/disclosure_tile.dart';
import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/secret_field_row.dart';
import '../../widgets/settings_scaffold.dart';
import 'provider_detail_view.dart' show providerApiTypeLabel;
import 'provider_form_models.dart';
import 'provider_form_parts.dart';
import 'provider_row_actions.dart';
import 'provider_view_models.dart';

/// The bar title of the form: "Add custom endpoint" or "Edit &lt;name&gt;".
String endpointFormTitle(AppLocalizations l10n, EndpointFormData data) =>
    data.editing
    ? l10n.providersEndpointFormTitleEdit(data.endpointName)
    : l10n.providersEndpointFormTitleNew;

/// The bar's Save, a spinner while saving. The screen decides [canSave] with
/// [EndpointFormData.canSave] from its text controllers.
SettingsFormAction endpointFormAction(
  AppLocalizations l10n,
  EndpointFormData data, {
  required bool canSave,
  VoidCallback? onSave,
}) => SettingsFormAction(
  label: l10n.providersFormSave,
  busy: data.saving,
  onPressed: canSave ? onSave : null,
);

/// The body of the custom endpoint form, from a plain [EndpointFormData]:
/// Name, Address and API key as three groups with their footers, "Check
/// connection" under them and its result (a banner, then the models found as
/// a menu and "Hermes will use &lt;address&gt;"), the collapsed Advanced section
/// (API type, and the model typed by hand when the endpoint lists none) and
/// "Use for new chats".
///
/// The key follows the secret field rule: hidden while a check or save runs
/// and after a failure, kept through a plain failure, cleared here when the
/// answer to a save was lost. The screen owns the four controllers, clears
/// the key's when App Lock locks and when the form closes, and sends the key
/// only when the person typed one.
class EndpointForm extends StatefulWidget {
  const EndpointForm({
    super.key,
    required this.data,
    required this.nameController,
    required this.addressController,
    required this.keyController,
    required this.modelController,
    this.initiallyShown = false,
    this.initiallyAdvancedOpen = false,
    this.onEdited,
    this.onCheck,
    this.onModelSelected,
    this.onApiTypeChanged,
    this.onUseForNewChanged,
    this.onRemoveSavedKey,
  });

  final EndpointFormData data;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController keyController;
  final TextEditingController modelController;

  /// Only the catalog sets these, to draw a shown key and an open Advanced.
  final bool initiallyShown;
  final bool initiallyAdvancedOpen;

  /// Any of the four fields changed.
  final VoidCallback? onEdited;
  final VoidCallback? onCheck;
  final ValueChanged<String>? onModelSelected;
  final ValueChanged<ProviderApiType>? onApiTypeChanged;
  final ValueChanged<bool>? onUseForNewChanged;

  /// "Remove saved key" was tapped; the screen asks before it removes.
  final VoidCallback? onRemoveSavedKey;

  @override
  State<EndpointForm> createState() => _EndpointFormState();
}

class _EndpointFormState extends State<EndpointForm> {
  final _modelFocus = FocusNode();
  late var _advancedOpen = widget.initiallyAdvancedOpen;

  // A new key forces the tile to rebuild open when a check found no models.
  var _advancedGeneration = 0;
  var _hideSignal = 0;

  @override
  void didUpdateWidget(EndpointForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.data;
    final now = widget.data;
    if (was.check != EndpointCheck.noModels &&
        now.check == EndpointCheck.noModels) {
      // Nothing to pick: Advanced opens with the Model field focused.
      _advancedOpen = true;
      _advancedGeneration++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _modelFocus.requestFocus();
      });
    }
    final failed =
        (!was.unknown && now.unknown) ||
        (!was.refused && now.refused) ||
        (!was.notAccepted && now.notAccepted) ||
        (was.issue != now.issue && now.issue != EndpointFormIssue.none);
    if (failed) _hideSignal++;
    if (!was.unknown && now.unknown) {
      // The answer was lost: the key may be saved already, so the field is
      // emptied.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.data.unknown) widget.keyController.clear();
      });
    }
  }

  @override
  void dispose() {
    _modelFocus.dispose();
    super.dispose();
  }

  Widget _banner(Widget banner) =>
      Padding(padding: const EdgeInsets.only(top: 12), child: banner);

  Widget _checkResult(AppLocalizations l10n) {
    final data = widget.data;
    switch (data.check) {
      case EndpointCheck.none:
        return const SizedBox.shrink();
      case EndpointCheck.checking:
        return ProviderStatusLine(l10n.providersEndpointChecking);
      case EndpointCheck.found:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(
              AppBanner(
                tone: AppBannerTone.success,
                title: l10n.providersEndpointFound(data.models.length),
              ),
            ),
            _modelChoice(l10n),
            if (data.resolvedAddress != null)
              GroupedFooter(
                l10n.providersEndpointWillUse(data.resolvedAddress!),
              ),
          ],
        );
      case EndpointCheck.noModels:
        final warning = data.warning;
        return _banner(
          AppBanner(
            tone: AppBannerTone.warning,
            title: warning ?? l10n.providersEndpointNoModelsTitle,
            detail: warning == null ? l10n.providersEndpointNoModelsDetail : '',
          ),
        );
      case EndpointCheck.unreachable:
        return _banner(
          AppBanner(
            tone: AppBannerTone.error,
            title: l10n.providersEndpointUnreachableTitle,
            detail: l10n.providersEndpointUnreachableDetail(
              data.checkedAddress,
            ),
          ),
        );
      case EndpointCheck.failed:
        return _banner(
          AppBanner(
            tone: AppBannerTone.warning,
            title: l10n.providersEndpointCheckFailedTitle,
            detail: l10n.providersEndpointCheckFailedDetail,
          ),
        );
    }
  }

  /// The models found: a menu with the first selected, or at a large text
  /// size, where a menu row would cut its label and value, one row per model
  /// under a "Model" header.
  Widget _modelChoice(AppLocalizations l10n) {
    final data = widget.data;
    if (MediaQuery.textScalerOf(context).scale(14) <= 21) {
      return GroupedSection(
        children: [
          GroupedMenuRow<String>(
            title: l10n.providersEndpointModelLabel,
            options: data.models,
            labelOf: (model) => model,
            selected: data.selectedModel,
            onSelected: (model) => widget.onModelSelected?.call(model),
          ),
        ],
      );
    }
    return RadioGroup<String>(
      groupValue: data.selectedModel,
      onChanged: (model) {
        if (model != null) widget.onModelSelected?.call(model);
      },
      child: GroupedSection(
        header: l10n.providersEndpointModelLabel,
        dividerIndent: GroupedChoiceRow.dividerIndent(context),
        children: [
          for (final model in data.models)
            GroupedChoiceRow<String>(
              value: model,
              title: model,
              titleMaxLines: null,
            ),
        ],
      ),
    );
  }

  Widget _advanced(BuildContext context, AppLocalizations l10n) {
    final metrics = GroupedMetrics.of(context);
    final data = widget.data;
    final muted = context.hermesColors.subtleText;
    final footerStyle = TextStyle(fontSize: metrics.footerSize, color: muted);
    final divider = Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return GroupedSection(
      children: [
        DisclosureTile(
          key: ValueKey(_advancedGeneration),
          initiallyExpanded: _advancedOpen,
          onExpansionChanged: (open) => _advancedOpen = open,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: Text(
            l10n.providersEndpointAdvanced,
            style: TextStyle(
              fontSize: metrics.titleSize,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          children: [
            divider,
            Semantics(
              container: true,
              label: l10n.providersEndpointApiType,
              child: RadioGroup<ProviderApiType>(
                groupValue: data.apiType,
                onChanged: (type) {
                  if (type != null) widget.onApiTypeChanged?.call(type);
                },
                child: Column(
                  children: [
                    for (final (i, type) in ProviderApiType.values.indexed) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: GroupedChoiceRow.dividerIndent(context),
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      GroupedChoiceRow<ProviderApiType>(
                        value: type,
                        title: providerApiTypeLabel(l10n, type),
                        titleMaxLines: null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.rowPadding,
                6,
                metrics.rowPadding,
                10,
              ),
              child: Text(
                l10n.providersEndpointApiTypeFooter,
                style: footerStyle,
              ),
            ),
            divider,
            GroupedTextFieldRow(
              labelWidth: _labelWidth,
              label: l10n.providersEndpointModelLabel,
              hint: l10n.providersEndpointModelHint,
              controller: widget.modelController,
              focusNode: _modelFocus,
              enabled: !data.saving,
              autocorrect: false,
              enableSuggestions: false,
              monospace: true,
              onChanged: (_) => widget.onEdited?.call(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.rowPadding,
                0,
                metrics.rowPadding,
                10,
              ),
              child: Text(
                l10n.providersEndpointModelFooter,
                style: footerStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _useForNew(AppLocalizations l10n) {
    final data = widget.data;
    if (data.editing) return const SizedBox.shrink();
    if (!data.offersUseForNew) {
      return GroupedFooter(l10n.providersEndpointFirstFooter(data.profile));
    }
    final current = data.currentModelName;
    return GroupedSection(
      footer: current == null
          ? null
          : l10n.providersEndpointUseForNewFooter(current),
      children: [
        GroupedSwitchRow(
          title: l10n.providersEndpointUseForNew,
          titleMaxLines: null,
          value: data.useForNew,
          onChanged: data.saving ? null : widget.onUseForNewChanged,
        ),
      ],
    );
  }

  String? _issue(AppLocalizations l10n, EndpointFormIssue issue) =>
      switch (issue) {
        EndpointFormIssue.none => null,
        EndpointFormIssue.name => l10n.providersEndpointIssueName,
        EndpointFormIssue.address => l10n.providersEndpointIssueAddress,
        EndpointFormIssue.scheme => l10n.providersEndpointIssueScheme,
        EndpointFormIssue.model => l10n.providersEndpointIssueModel,
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _labelWidth = groupedLabelWidth(context, [
        context.l10n.providersEndpointNameLabel,
        context.l10n.providersEndpointAddress,
        context.l10n.providersEndpointKey,
        context.l10n.providersEndpointModelLabel,
      ], available: box.maxWidth);
      return _form(context);
    },
  );

  /// The label column all four fields share, so they start at the same x.
  double _labelWidth = 0;

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final data = widget.data;
    final issue = data.issue;
    final refused = data.notAccepted
        ? l10n.providersNotAccepted
        : data.message ?? l10n.providersEndpointRefusedFallback;
    final showRefused = data.refused || data.notAccepted;
    final keyFooter = data.editing && data.hasSavedKey
        ? l10n.providersEndpointKeyFooterEdit
        : l10n.providersEndpointKeyFooter;
    return GroupedListView(
      children: [
        if (data.unknown)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersEndpointUnknownTitle,
              detail: l10n.providersEndpointUnknownDetail,
            ),
          ),
        GroupedSection(
          children: [
            GroupedTextFieldRow(
              labelWidth: _labelWidth,
              label: l10n.providersEndpointNameLabel,
              hint: l10n.providersEndpointNameHint,
              controller: widget.nameController,
              enabled: !data.saving,
              textInputAction: TextInputAction.next,
              onChanged: (_) => widget.onEdited?.call(),
            ),
          ],
        ),
        if (issue == EndpointFormIssue.name)
          ProviderFieldProblem(l10n.providersEndpointIssueName),
        GroupedFooter(l10n.providersEndpointNameFooter),
        GroupedSection(
          children: [
            GroupedTextFieldRow(
              labelWidth: _labelWidth,
              label: l10n.providersEndpointAddress,
              hint: l10n.providersEndpointAddressHint,
              controller: widget.addressController,
              enabled: !data.saving,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => widget.onEdited?.call(),
            ),
          ],
        ),
        if (issue == EndpointFormIssue.address ||
            issue == EndpointFormIssue.scheme)
          ProviderFieldProblem(_issue(l10n, issue)!),
        GroupedFooter(l10n.providersEndpointAddressFooter),
        GroupedSection(
          children: [
            SecretFieldRow(
              labelWidth: _labelWidth,
              label: l10n.providersEndpointKey,
              hint: data.editing && data.hasSavedKey
                  ? l10n.providersEndpointKeySavedHint
                  : l10n.providersEndpointKeyHint,
              controller: widget.keyController,
              enabled: !data.saving,
              busy: data.busy,
              hideSignal: _hideSignal,
              initiallyShown: widget.initiallyShown,
              onChanged: (_) => widget.onEdited?.call(),
            ),
            if (data.editing && data.hasSavedKey)
              GroupedRow(
                title: l10n.providersEndpointKeyRemove,
                titleMaxLines: null,
                destructive: true,
                chevron: false,
                onTap: data.busy ? null : widget.onRemoveSavedKey,
              ),
          ],
        ),
        GroupedFooter(keyFooter),
        if (data.insecureKey)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersEndpointInsecureTitle,
              detail: l10n.providersEndpointInsecureDetail,
            ),
          ),
        ListenableBuilder(
          listenable: widget.addressController,
          builder: (context, _) => ProviderActionStack(
            buttons: (full) => [
              ProviderRowButton(
                label: l10n.providersEndpointCheck,
                outlined: true,
                fullWidth: full,
                onPressed:
                    data.busy || widget.addressController.text.trim().isEmpty
                    ? null
                    : widget.onCheck,
              ),
            ],
          ),
        ),
        _checkResult(l10n),
        if (data.keyNotSent)
          _banner(
            AppBanner(
              tone: AppBannerTone.neutral,
              title: l10n.providersEndpointKeyNotSentTitle,
              detail: l10n.providersEndpointKeyNotSentDetail,
            ),
          ),
        _advanced(context, l10n),
        _useForNew(l10n),
        if (issue == EndpointFormIssue.model)
          ProviderFieldProblem(l10n.providersEndpointIssueModel),
        if (showRefused) ProviderFieldProblem(refused),
        if (data.saving) ProviderStatusLine(l10n.providersSaving),
      ],
    );
  }
}
