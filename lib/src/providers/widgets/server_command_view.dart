import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/command_row.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/settings_scaffold.dart';
import 'provider_form_models.dart';
import 'provider_form_parts.dart';
import 'provider_row_actions.dart';

/// The bar's Done of the page: the bar says only the provider's name, and the
/// long title is the page's heading. The screen puts it in its
/// [SettingsScaffold].
SettingsFormAction serverCommandFormAction(
  AppLocalizations l10n, {
  VoidCallback? onDone,
}) => SettingsFormAction(label: l10n.providersServerDone, onPressed: onDone);

/// "Connect &lt;provider&gt; on your server": the app cannot do this one, so it
/// says how. The command Hermes gives sits in the shared [CommandRow]
/// (selectable, with Copy) and "Check again", the one filled button, reads
/// the providers again. The app starts nothing itself.
class ServerCommandView extends StatelessWidget {
  const ServerCommandView({super.key, required this.data, this.onCheckAgain});

  final ServerCommandData data;
  final VoidCallback? onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    return GroupedListView(
      children: [
        ProviderHeading(
          title: l10n.providersServerTitle(data.providerName),
          body: l10n.providersServerBody(data.providerName),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            16,
            metrics.rowPadding,
            0,
          ),
          child: CommandRow(command: data.command, copyBelowAtLargeText: true),
        ),
        GroupedFooter(l10n.providersServerFooter(data.profile)),
        ProviderActionStack(
          buttons: (full) => [
            ProviderRowButton(
              label: l10n.providersCheckAgain,
              filled: true,
              fullWidth: full,
              onPressed: data.checking ? null : onCheckAgain,
            ),
          ],
        ),
        if (data.checking) ProviderStatusLine(l10n.providersServerChecking),
      ],
    );
  }
}
