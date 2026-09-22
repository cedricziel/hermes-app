import 'package:flutter/material.dart';

import '../model_provider_option.dart';
import 'effort_menu_button.dart';
import 'model_menu_button.dart';

/// Sits above the composer on a new chat: pick a model and, if it takes one,
/// a reasoning effort, before the first message creates the session. The
/// server applies both only to sessions started after the choice, so once a
/// chat has a session there is nothing left here to change.
class NewChatModelBar extends StatelessWidget {
  const NewChatModelBar({
    super.key,
    required this.providers,
    required this.selectedProviderId,
    required this.selectedModelId,
    this.selectedEffort,
    required this.onModelSelected,
    required this.onEffortSelected,
    this.onRefreshModels,
    this.onEditModels,
  });

  final List<ModelProviderOption> providers;
  final String selectedProviderId;
  final String selectedModelId;
  final String? selectedEffort;
  final void Function(String providerId, String modelId) onModelSelected;
  final ValueChanged<String> onEffortSelected;
  final VoidCallback? onRefreshModels;
  final VoidCallback? onEditModels;

  List<String> get _effortOptions {
    for (final provider in providers) {
      if (provider.id != selectedProviderId) continue;
      for (final model in provider.models) {
        if (model.id == selectedModelId) return model.supportedEfforts;
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ModelMenuButton(
            providers: providers,
            selectedProviderId: selectedProviderId,
            selectedModelId: selectedModelId,
            onModelSelected: onModelSelected,
            onRefresh: onRefreshModels,
            onEditModels: onEditModels,
          ),
          const SizedBox(width: 8),
          EffortMenuButton(
            options: _effortOptions,
            selected: selectedEffort,
            onSelected: onEffortSelected,
          ),
        ],
      ),
    );
  }
}
