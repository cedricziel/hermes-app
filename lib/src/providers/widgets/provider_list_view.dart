import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/settings_search_field.dart';
import '../../widgets/state_message.dart';
import 'model_provider_row.dart';
import 'provider_view_models.dart';

/// The most entries "Add a provider" lists before it offers a search field.
const kProviderSearchThreshold = 12;

/// The bar's subtitle of the Model providers screen: the profile and how many
/// providers it has connected.
String providerListSubtitle(
  AppLocalizations l10n,
  String profile,
  int connectedCount,
) => connectedCount == 0
    ? profile
    : '$profile · ${l10n.providersConnectedCount(connectedCount)}';

/// The body of the Model providers screen, from a plain [ProviderListData]:
/// the default model, the connected providers and "Add a provider", or the
/// one message that stands in for them while loading, offline or failed. A
/// source that failed shows a warning banner with "Try again" right above the
/// part it feeds; a section the server does not offer is simply absent.
///
/// The search field shows on its own above the providers to add when
/// [onSearchChanged] is set and there are more than
/// [kProviderSearchThreshold]; a Mac window searches from its toolbar, so it
/// only filters by [searchQuery] there.
class ProviderListView extends StatelessWidget {
  const ProviderListView({
    super.key,
    required this.data,
    this.selectedId,
    this.searchQuery = '',
    this.onSearchChanged,
    this.onSelect,
    this.onAdd,
    this.onAddEndpoint,
    this.onOpenDefaultModel,
    this.onContinueSignIn,
    this.onStopSignIn,
    this.onRetry,
    this.onRetryKeys,
    this.onRetryAccounts,
    this.onRetryEndpoints,
    this.scrollController,
    this.scrollPhysics,
    this.addHeadingKey,
  });

  final ProviderListData data;

  /// The connected provider whose detail shows beside the list.
  final String? selectedId;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;

  /// A connected provider was tapped.
  final ValueChanged<String>? onSelect;

  /// A provider to add was tapped.
  final ValueChanged<String>? onAdd;
  final VoidCallback? onAddEndpoint;
  final VoidCallback? onOpenDefaultModel;
  final ValueChanged<String>? onContinueSignIn;
  final ValueChanged<String>? onStopSignIn;

  /// Reads everything again.
  final VoidCallback? onRetry;
  final VoidCallback? onRetryKeys;
  final VoidCallback? onRetryAccounts;
  final VoidCallback? onRetryEndpoints;

  /// The list's scroll controller, and its physics: the screen passes
  /// always-scrollable physics where it pulls to refresh.
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;

  /// Put on the "Add a provider" heading, so the screen can scroll to it.
  final Key? addHeadingKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (data.status) {
      case ProviderListStatus.loading:
        return _loading(context, l10n);
      case ProviderListStatus.failed:
        return StateMessage(
          icon: AppIcons.error,
          title: l10n.providersLoadFailedTitle,
          detail: data.failureReason ?? l10n.providersLoadFailedDetail,
          action: _retry(l10n, onRetry, filled: true),
        );
      case ProviderListStatus.offline:
        return StateMessage(
          icon: AppIcons.warning,
          title: l10n.providersOfflineTitle,
          detail: l10n.providersOfflineStateDetail,
          action: _retry(l10n, onRetry, filled: true),
        );
      case ProviderListStatus.loaded:
        return _loaded(context, l10n);
    }
  }

  Widget _retry(
    AppLocalizations l10n,
    VoidCallback? onPressed, {
    bool filled = false,
  }) => filled
      ? FilledButton(onPressed: onPressed, child: Text(l10n.providersTryAgain))
      : TextButton(onPressed: onPressed, child: Text(l10n.providersTryAgain));

  Widget _loading(
    BuildContext context,
    AppLocalizations l10n,
  ) => GroupedListView(
    physics: const NeverScrollableScrollPhysics(),
    children: [
      GroupedSection(
        header: l10n.providersConnectedHeader,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: LoadingSkeleton(label: l10n.providersLoadingLabel, lines: 4),
          ),
        ],
      ),
    ],
  );

  Widget _banner(Widget banner) =>
      Padding(padding: const EdgeInsets.only(top: 12), child: banner);

  List<ModelProviderRowData> _filtered(
    AppLocalizations l10n,
    List<ModelProviderRowData> rows,
  ) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return [
      for (final row in rows)
        if (row.name.toLowerCase().contains(query)) row,
    ];
  }

  Widget _row(ModelProviderRowData row) {
    final onTap = switch (row.connection) {
      ProviderConnection.pendingSignIn => null,
      ProviderConnection.offerEndpoint => onAddEndpoint,
      ProviderConnection.offerKey ||
      ProviderConnection.offerAccount ||
      ProviderConnection.offerOnServer =>
        onAdd == null ? null : () => onAdd!(row.id),
      ProviderConnection.key ||
      ProviderConnection.signedIn ||
      ProviderConnection.endpoint ||
      ProviderConnection.connected =>
        onSelect == null ? null : () => onSelect!(row.id),
    };
    return ModelProviderRow(
      key: row.id.isEmpty ? null : ValueKey('provider-row-${row.id}'),
      provider: row,
      selected: row.id == selectedId && !row.isPending,
      onTap: onTap,
      onContinueSignIn: onContinueSignIn == null
          ? null
          : () => onContinueSignIn!(row.id),
      onStopSignIn: onStopSignIn == null ? null : () => onStopSignIn!(row.id),
    );
  }

  Widget _loaded(BuildContext context, AppLocalizations l10n) {
    final metrics = GroupedMetrics.of(context);
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final scheme = Theme.of(context).colorScheme;
    final defaultModel = data.defaultModel;
    final searchable = data.addableCount > kProviderSearchThreshold;
    final recommended = _filtered(l10n, data.recommended);
    final more = _filtered(l10n, data.more);
    final endpoint = ModelProviderRowData(
      id: '',
      name: l10n.providersCustomEndpointTitle,
      connection: ProviderConnection.offerEndpoint,
    );
    final showEndpoint =
        data.endpointOffered && _filtered(l10n, [endpoint]).isNotEmpty;
    final nothingFound =
        searchQuery.trim().isNotEmpty &&
        recommended.isEmpty &&
        more.isEmpty &&
        !showEndpoint;
    return GroupedListView(
      controller: scrollController,
      physics: scrollPhysics,
      children: [
        if (data.restartRequired)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersRestartTitle,
              detail: l10n.providersRestartDetail,
            ),
          ),
        if (data.staleOffline)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersOfflineTitle,
              detail: l10n.providersOfflineBannerDetail,
              action: _retry(l10n, onRetry),
            ),
          ),
        if (data.connected.isEmpty)
          StateMessage(
            title: l10n.providersEmptyTitle,
            detail: l10n.providersEmptyDetail(data.profile),
          ),
        if (defaultModel != null && data.connected.isNotEmpty)
          GroupedSection(
            header: l10n.providersDefaultModelHeader,
            footer: l10n.providersDefaultModelFooter(data.profile),
            children: [
              GroupedRow(
                title: defaultModel.name,
                titleMaxLines: null,
                meta: defaultModel.providerName,
                subtitle: defaultModel.id,
                subtitleMaxLines: null,
                onTap: onOpenDefaultModel,
              ),
            ],
          ),
        if (data.keysFailed)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersKeysFailed,
              action: _retry(l10n, onRetryKeys),
            ),
          ),
        if (data.connected.isNotEmpty)
          GroupedSection(
            header: l10n.providersConnectedHeader,
            children: [for (final row in data.connected) _row(row)],
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            metrics.sectionGap + 4,
            metrics.rowPadding,
            0,
          ),
          child: Semantics(
            key: addHeadingKey,
            header: true,
            child: Text(
              l10n.providersAddHeading,
              style: TextStyle(
                fontSize: mac ? 15 : 20,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        if (data.accountsFailed)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersAccountsFailed,
              action: _retry(l10n, onRetryAccounts),
            ),
          ),
        if (searchable && !mac && onSearchChanged != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SettingsSearchField(
              search: SettingsSearch(
                query: searchQuery,
                hint: l10n.providersSearchHint,
                onChanged: onSearchChanged!,
              ),
            ),
          ),
        if (recommended.isNotEmpty)
          GroupedSection(
            header: l10n.providersRecommendedHeader,
            children: [for (final row in recommended) _row(row)],
          ),
        if (more.isNotEmpty)
          GroupedSection(
            header: l10n.providersMoreHeader,
            children: [for (final row in more) _row(row)],
          ),
        if (data.endpointsFailed)
          _banner(
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersEndpointsFailed,
              action: _retry(l10n, onRetryEndpoints),
            ),
          ),
        if (showEndpoint)
          GroupedSection(
            footer: l10n.providersPrivacyFooter(data.profile),
            children: [_row(endpoint)],
          )
        else if (nothingFound)
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              16,
              metrics.rowPadding,
              0,
            ),
            child: Text(
              l10n.providersSearchNoMatch,
              style: TextStyle(color: context.hermesColors.subtleText),
            ),
          ),
        if (!showEndpoint)
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              12,
              metrics.rowPadding,
              0,
            ),
            child: Text(
              l10n.providersPrivacyFooter(data.profile),
              style: TextStyle(
                fontSize: metrics.footerSize,
                color: context.hermesColors.subtleText,
              ),
            ),
          ),
      ],
    );
  }
}
