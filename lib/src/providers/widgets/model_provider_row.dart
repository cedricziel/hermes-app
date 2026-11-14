import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';
import 'provider_row_actions.dart';
import 'provider_view_models.dart';

/// How a provider is, or can be, connected, in words: the row's subtitle.
/// [spoken] spaces out the last four characters so a screen reader reads
/// them one by one ("4 f 2 a").
String providerRowState(
  AppLocalizations l10n,
  ModelProviderRowData provider, {
  bool spoken = false,
}) {
  final lastFour = provider.lastFour;
  final email = provider.email;
  final host = provider.host;
  return switch (provider.connection) {
    ProviderConnection.key =>
      lastFour == null || lastFour.isEmpty
          ? l10n.providersRowKeySaved
          : l10n.providersRowKeyEnding(
              spoken ? lastFour.split('').join(' ') : lastFour,
            ),
    ProviderConnection.signedIn =>
      email == null || email.isEmpty
          ? l10n.providersRowSignedIn
          : l10n.providersRowSignedInAs(email),
    ProviderConnection.endpoint =>
      host == null || host.isEmpty
          ? l10n.providersCustomEndpointTitle
          : l10n.providersRowEndpoint(host),
    ProviderConnection.connected => l10n.providersRowConnected,
    ProviderConnection.pendingSignIn => l10n.providersRowWaiting,
    ProviderConnection.offerKey => l10n.providersRowOfferKey,
    ProviderConnection.offerAccount => l10n.providersRowOfferAccount,
    ProviderConnection.offerOnServer => l10n.providersRowOfferOnServer,
    ProviderConnection.offerEndpoint => l10n.providersCustomEndpointHint,
  };
}

/// A model provider in the list: its name, how it is connected (or how it
/// connects), "Default" when it serves the default model and a warning line
/// when Hermes reports one. Text always wraps. A provider waiting for sign-in
/// has no chevron: it offers a text "Stop" and an outlined "Continue", beside
/// the text (small push buttons on a Mac) or, at a large text size, below it
/// at full width with Continue first.
///
/// Named so to stay apart from the toolsets' radio `ProviderRow`.
class ModelProviderRow extends StatelessWidget {
  const ModelProviderRow({
    super.key,
    required this.provider,
    this.selected = false,
    this.onTap,
    this.onContinueSignIn,
    this.onStopSignIn,
  });

  final ModelProviderRowData provider;

  /// Highlights the provider whose detail shows beside the list.
  final bool selected;

  /// Opens the provider's detail, or starts connecting it.
  final VoidCallback? onTap;
  final VoidCallback? onContinueSignIn;
  final VoidCallback? onStopSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = providerRowState(l10n, provider);
    final warning = provider.warning;
    if (provider.isPending) return _pending(context, l10n, state);
    final large = providerLargeText(context);
    final spoken = providerRowState(l10n, provider, spoken: true);
    final label = [
      provider.isDefault
          ? l10n.providersRowSemanticsDefault(provider.name, spoken)
          : l10n.providersRowSemantics(provider.name, spoken),
      ?warning,
    ].join('. ');
    // The row reads as one sentence; the whole of it is the button.
    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GroupedRow(
        title: provider.name,
        titleMaxLines: null,
        // "Default" is a word next to the name, and on a line of its own when
        // the text is large.
        meta: provider.isDefault && !large ? l10n.providersDefaultBadge : null,
        subtitle: state,
        subtitleMaxLines: null,
        caption: provider.isDefault && large
            ? l10n.providersDefaultBadge
            : null,
        warning: warning,
        selected: selected,
        onTap: onTap,
      ),
    );
  }

  Widget _pending(BuildContext context, AppLocalizations l10n, String state) {
    return ProviderActionRow(
      row: (trailing) => GroupedRow(
        title: provider.name,
        titleMaxLines: null,
        subtitle: state,
        subtitleMaxLines: null,
        trailing: trailing,
        separateTrailing: true,
      ),
      actions: (stacked) {
        final stop = ProviderRowButton(
          label: l10n.providersRowStop,
          semanticsLabel: l10n.providersRowStopSemantics(provider.name),
          onPressed: onStopSignIn,
          fullWidth: stacked,
        );
        final resume = ProviderRowButton(
          label: l10n.providersRowContinue,
          semanticsLabel: l10n.providersRowContinueSemantics(provider.name),
          onPressed: onContinueSignIn,
          outlined: true,
          fullWidth: stacked,
        );
        return stacked ? [resume, stop] : [stop, resume];
      },
    );
  }
}
