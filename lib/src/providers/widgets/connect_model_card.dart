import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import 'provider_form_models.dart';
import 'provider_form_parts.dart';
import 'provider_row_actions.dart';

/// The widest a [ConnectModelCard] grows: on a Mac or a wide window it is
/// centred in the welcome area at this width.
const kConnectModelCardMaxWidth = 420.0;

/// The card that replaces the chat's starter prompts when the profile has no
/// usable model, from a plain [ConnectCardData]: a bordered surface (no
/// shadow) with a 36 pt icon tile, a title, the body and one full-width filled
/// button. "Connect a model" and "Reconnect" open Model providers; "Check
/// again" (while a provider's models load) reads the chat's model options
/// again and does not lead to Connect.
class ConnectModelCard extends StatelessWidget {
  const ConnectModelCard({super.key, required this.data, this.onPressed});

  final ConnectCardData data;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, body, action) = switch (data.kind) {
      ConnectCardKind.connect => (
        AppIcons.tune,
        l10n.providersCardConnectTitle,
        data.profile == 'default'
            ? l10n.providersCardConnectBodyDefault
            : l10n.providersCardConnectBody(data.profile),
        l10n.providersCardConnect,
      ),
      ConnectCardKind.reconnect => (
        AppIcons.lock,
        l10n.providersCardReconnectTitle,
        data.profile == 'default'
            ? l10n.providersCardReconnectBodyDefault(data.modelName ?? '')
            : l10n.providersCardReconnectBody(
                data.profile,
                data.modelName ?? '',
              ),
        l10n.providersCardReconnect,
      ),
      ConnectCardKind.loading => (
        AppIcons.waiting,
        l10n.providersCardLoadingTitle,
        l10n.providersCardLoadingBody,
        l10n.providersCheckAgain,
      ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kConnectModelCardMaxWidth),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(kHermesRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ProviderIconTile(icon: icon, size: 36),
              ),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  color: context.hermesColors.subtleText,
                ),
              ),
              ProviderRowButton(
                label: action,
                filled: true,
                fullWidth: true,
                onPressed: onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed reply that came from the model provider (a bad key, no credit):
/// the error as an error banner, and under it an outlined "Check model
/// providers" that opens the default model's provider.
class ProviderReplyFailure extends StatelessWidget {
  const ProviderReplyFailure({
    super.key,
    required this.message,
    this.onCheckProviders,
  });

  /// The error the reply failed with.
  final String message;
  final VoidCallback? onCheckProviders;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        AppBanner(
          tone: AppBannerTone.error,
          title: l10n.providersReplyFailedTitle,
          detail: message,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ProviderRowButton(
            label: l10n.providersReplyCheckProviders,
            outlined: true,
            onPressed: onCheckProviders,
          ),
        ),
      ],
    );
  }
}
