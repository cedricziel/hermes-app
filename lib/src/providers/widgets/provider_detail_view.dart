import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/command_row.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/settings_scaffold.dart';
import 'provider_row_actions.dart';
import 'provider_view_models.dart';

/// How many model ids the detail lists before "Show all".
const kProviderModelsShown = 5;

/// The bar's buttons of a provider's detail: "Edit" for a custom endpoint,
/// none otherwise. The screen puts them in its [SettingsScaffold].
List<SettingsBarAction> providerDetailBarActions(
  AppLocalizations l10n,
  ProviderDetailData data, {
  VoidCallback? onEdit,
}) => [
  if (data.endpoint != null && onEdit != null)
    SettingsBarAction(
      label: l10n.providersDetailEdit,
      icon: AppIcons.edit,
      onPressed: onEdit,
    ),
];

/// An endpoint's API type in words.
String providerApiTypeLabel(AppLocalizations l10n, ProviderApiType type) =>
    switch (type) {
      ProviderApiType.automatic => l10n.providersApiTypeAutomatic,
      ProviderApiType.chatCompletions => l10n.providersApiTypeChatCompletions,
      ProviderApiType.responses => l10n.providersApiTypeResponses,
      ProviderApiType.anthropicMessages =>
        l10n.providersApiTypeAnthropicMessages,
    };

/// One provider's detail, from a plain [ProviderDetailData]: how it is
/// connected, the default model with Change, its credentials with their
/// buttons, its models with "Show all", and the removal rows alone in the last
/// group. A removal is red text, never a filled button. Keys added by hand on
/// the server are listed read-only, with no removal; a sign-in Hermes cannot
/// remove shows the command to run on the server instead.
class ProviderDetailView extends StatefulWidget {
  const ProviderDetailView({
    super.key,
    required this.data,
    this.onChangeDefaultModel,
    this.onReplaceKey,
    this.onRemove,
  });

  final ProviderDetailData data;
  final VoidCallback? onChangeDefaultModel;

  /// Replace key was tapped on the credential with this id.
  final ValueChanged<String>? onReplaceKey;
  final ValueChanged<ProviderRemovalData>? onRemove;

  @override
  State<ProviderDetailView> createState() => _ProviderDetailViewState();
}

class _ProviderDetailViewState extends State<ProviderDetailView> {
  bool _allModels = false;

  ProviderDetailData get _data => widget.data;

  String _status(AppLocalizations l10n) {
    final email = _data.email;
    return switch (_data.status) {
      ProviderStatusKind.key => l10n.providersDetailStatusKey,
      ProviderStatusKind.signedIn =>
        email == null || email.isEmpty
            ? l10n.providersDetailStatusSignedIn
            : l10n.providersDetailStatusSignedInAs(email),
      ProviderStatusKind.endpoint => l10n.providersDetailStatusEndpoint,
      ProviderStatusKind.serverKey =>
        l10n.providersDetailStatusConnectedOnServer,
      ProviderStatusKind.none => l10n.providersDetailStatusNone,
    };
  }

  Widget _statusLine(BuildContext context, AppLocalizations l10n) {
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final none = _data.status == ProviderStatusKind.none;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        16,
        metrics.rowPadding,
        4,
      ),
      child: Semantics(
        container: true,
        label: _status(l10n),
        excludeSemantics: true,
        // The icon sits in the first line, so a wrapped sentence flows under
        // it at a large text size.
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: AppIcon(
                    none ? AppIcons.info : AppIcons.checkCircle,
                    size: metrics.titleSize + 2,
                    color: none ? colors.subtleText : colors.success,
                  ),
                ),
              ),
              TextSpan(text: _status(l10n)),
            ],
          ),
          style: TextStyle(
            fontSize: metrics.titleSize + 1,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _defaultModel(AppLocalizations l10n) {
    final model = _data.defaultModel!;
    final onChange = widget.onChangeDefaultModel;
    return GroupedSection(
      header: l10n.providersDefaultModelHeader,
      footer: l10n.providersDetailDefaultFooter(_data.profile),
      children: [
        ProviderActionRow(
          row: (trailing) => GroupedRow(
            title: model.name,
            titleMaxLines: null,
            subtitle: model.id,
            subtitleMaxLines: null,
            trailing: trailing,
            separateTrailing: true,
          ),
          actions: (stacked) => [
            ProviderRowButton(
              label: l10n.providersDetailChange,
              semanticsLabel: l10n.providersDetailChangeSemantics,
              onPressed: onChange,
              fullWidth: stacked,
              outlined: stacked,
            ),
          ],
        ),
      ],
    );
  }

  Widget _credential(AppLocalizations l10n, ProviderCredentialData c) {
    final lastFour = c.lastFour;
    final known = lastFour != null && lastFour.isNotEmpty;
    switch (c.kind) {
      case ProviderCredentialKind.apiKey:
        final onReplace = widget.onReplaceKey;
        return ProviderActionRow(
          textLabel: known
              ? l10n.providersRowKeyEnding(lastFour.split('').join(' '))
              : null,
          row: (trailing) => GroupedRow(
            title: known
                ? l10n.providersRowKeyEnding(lastFour)
                : l10n.providersRowKeySaved,
            titleMaxLines: null,
            trailing: trailing,
            separateTrailing: true,
          ),
          actions: (stacked) => [
            ProviderRowButton(
              label: l10n.providersDetailReplaceKey,
              semanticsLabel: l10n.providersDetailReplaceKeySemantics(
                _data.name,
              ),
              onPressed: onReplace == null ? null : () => onReplace(c.id),
              outlined: true,
              fullWidth: stacked,
            ),
          ],
        );
      case ProviderCredentialKind.account:
        return GroupedRow(
          title: l10n.providersDetailSignedIn,
          titleMaxLines: null,
          subtitle: switch (c.account) {
            ProviderAccountLabel.none => null,
            ProviderAccountLabel.nousPortal => l10n.providersDetailAccountNous,
            ProviderAccountLabel.chatGpt => l10n.providersDetailAccountChatGpt,
          },
          subtitleMaxLines: null,
        );
      case ProviderCredentialKind.serverKey:
        return GroupedRow(
          title: known
              ? l10n.providersDetailSavedKeyEnding(lastFour)
              : l10n.providersDetailSavedKey,
          titleMaxLines: null,
          subtitle: l10n.providersDetailAddedOnServer,
          subtitleMaxLines: null,
        );
    }
  }

  Widget? _credentials(AppLocalizations l10n) {
    final endpoint = _data.endpoint;
    if (endpoint != null) {
      return GroupedSection(
        header: l10n.providersCustomEndpointTitle,
        children: [
          GroupedRow(
            title: l10n.providersEndpointAddress,
            titleMaxLines: null,
            // The address sits under the label in monospace, so half the row
            // never cuts it.
            subtitle: endpoint.address,
            subtitleMaxLines: null,
            monospaceSubtitle: true,
          ),
          GroupedRow(
            title: l10n.providersEndpointApiType,
            titleMaxLines: null,
            value: providerApiTypeLabel(l10n, endpoint.apiType),
          ),
          GroupedRow(
            title: l10n.providersEndpointKey,
            titleMaxLines: null,
            value: endpoint.hasKey
                ? l10n.providersEndpointKeySaved
                : l10n.providersEndpointKeyNone,
          ),
        ],
      );
    }
    if (_data.credentials.isEmpty) return null;
    final hasServerKey = _data.credentials.any(
      (c) => c.kind == ProviderCredentialKind.serverKey,
    );
    return GroupedSection(
      header: l10n.providersDetailCredentialsHeader,
      footer: hasServerKey ? l10n.providersDetailManageOnServer : null,
      children: [for (final c in _data.credentials) _credential(l10n, c)],
    );
  }

  Widget? _models(AppLocalizations l10n) {
    final models = _data.models;
    if (models.isEmpty) return null;
    final expandable = models.length > kProviderModelsShown;
    final shown = _allModels || !expandable
        ? models
        : models.take(kProviderModelsShown).toList();
    return GroupedSection(
      header: l10n.providersDetailModelsHeader(
        _data.modelCount < models.length ? models.length : _data.modelCount,
      ),
      children: [
        for (final id in shown) GroupedRow(title: id, titleMaxLines: null),
        if (expandable)
          GroupedRow(
            title: _allModels
                ? l10n.providersDetailShowFewer
                : l10n.providersDetailShowAll(models.length),
            titleMaxLines: null,
            chevron: false,
            trailing: AppIcon(
              _allModels ? AppIcons.expandLess : AppIcons.expandMore,
              size: 20,
              color: context.hermesColors.subtleText,
            ),
            onTap: () => setState(() => _allModels = !_allModels),
          ),
      ],
    );
  }

  String _removalLabel(AppLocalizations l10n, ProviderRemovalKind kind) =>
      switch (kind) {
        ProviderRemovalKind.removeKey => l10n.providersRemoveKey,
        ProviderRemovalKind.signOut => l10n.providersSignOut,
        ProviderRemovalKind.deleteEndpoint => l10n.providersDeleteEndpoint,
      };

  Widget _serverCommand(BuildContext context, AppLocalizations l10n) {
    final metrics = GroupedMetrics.of(context);
    final command = _data.serverCommand;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.gutter,
        metrics.sectionGap,
        metrics.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.rowPadding - 4),
            child: Text(
              _data.removalHint ?? l10n.providersDetailCantRemove,
              style: TextStyle(
                fontSize: metrics.footerSize,
                color: context.hermesColors.subtleText,
              ),
            ),
          ),
          if (command != null && command.isNotEmpty)
            CommandRow(command: command),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final still = _data.stillConnectedThrough;
    final credentials = _credentials(l10n);
    final models = _models(l10n);
    final onRemove = widget.onRemove;
    final hasCommand =
        (_data.serverCommand ?? '').isNotEmpty || _data.removalHint != null;
    return GroupedListView(
      children: [
        _statusLine(context, l10n),
        if (still > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppBanner(
              tone: AppBannerTone.neutral,
              title: l10n.providersDetailStillConnected(still),
            ),
          ),
        if (_data.defaultModel != null) _defaultModel(l10n),
        ?credentials,
        ?models,
        if (_data.removals.isNotEmpty)
          GroupedSection(
            children: [
              for (final removal in _data.removals)
                GroupedRow(
                  title: _removalLabel(l10n, removal.kind),
                  titleMaxLines: null,
                  destructive: true,
                  chevron: false,
                  onTap: onRemove == null ? null : () => onRemove(removal),
                ),
            ],
          ),
        if (hasCommand) _serverCommand(context, l10n),
      ],
    );
  }
}
