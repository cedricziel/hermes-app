import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/settings_scaffold.dart';
import 'provider_models.dart';
import 'provider_setup_controller.dart';
import 'provider_view_mapper.dart';
import 'widgets/provider_detail_view.dart';
import 'widgets/provider_view_models.dart';

/// What the detail's buttons do; the screen owns the dialogs and sheets.
class ProviderDetailActions {
  const ProviderDetailActions({
    required this.changeDefault,
    required this.replaceKey,
    required this.remove,
    required this.edit,
  });

  final VoidCallback changeDefault;
  final ValueChanged<ProviderEntry> replaceKey;
  final void Function(ProviderEntry entry, ProviderRemovalData removal) remove;
  final ValueChanged<ProviderEntry> edit;
}

/// One provider's detail, following [controller]: the pane beside the list
/// on a wide screen and the body of the pushed page on a narrow one.
class ProviderDetailPane extends StatelessWidget {
  const ProviderDetailPane({
    super.key,
    required this.controller,
    required this.providerId,
    required this.profile,
    required this.actions,
  });

  final ProviderSetupController controller;
  final String providerId;
  final String profile;
  final ProviderDetailActions actions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final entry = controller.catalog?.byId(providerId);
      if (entry == null) return const SizedBox.shrink();
      return ProviderDetailView(
        data: providerDetailData(entry, controller, profile: profile),
        onChangeDefaultModel: actions.changeDefault,
        onReplaceKey: (_) => actions.replaceKey(entry),
        onRemove: (removal) => actions.remove(entry, removal),
      );
    },
  );
}

/// A provider's detail as a pushed page, below the width that puts it beside
/// the list. It closes when the provider is no longer connected.
class ProviderDetailPage extends StatelessWidget {
  const ProviderDetailPage({
    super.key,
    required this.controller,
    required this.providerId,
    required this.profile,
    required this.actions,
  });

  final ProviderSetupController controller;
  final String providerId;
  final String profile;
  final ProviderDetailActions actions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final entry = controller.catalog?.byId(providerId);
      if (entry == null || !entry.connected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.of(context).maybePop();
          }
        });
      }
      final data = entry == null
          ? null
          : providerDetailData(entry, controller, profile: profile);
      return SettingsScaffold(
        title: entry?.name ?? '',
        subtitle: profile,
        previousTitle: context.l10n.providersListTitle,
        actions: data == null || entry == null
            ? const []
            : providerDetailBarActions(
                context.l10n,
                data,
                onEdit: () => actions.edit(entry),
              ),
        body: ProviderDetailPane(
          controller: controller,
          providerId: providerId,
          profile: profile,
          actions: actions,
        ),
      );
    },
  );
}
