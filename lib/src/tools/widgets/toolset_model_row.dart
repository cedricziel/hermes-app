import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';
import 'tools_load_state.dart';

/// Where the model catalog of image or video generation stands.
enum ToolsetModelRowPhase { loading, failed, ready }

/// The "Model" row of image and video generation: the current model as its
/// value, opening the model list. While the catalog is read it is a loading
/// row and when that failed a failure row with Try again; when [ready] the
/// footer says where prices come from and when a pick applies.
class ToolsetModelRow extends StatelessWidget {
  const ToolsetModelRow({
    super.key,
    required this.phase,
    required this.provider,
    this.value,
    this.onOpen,
    this.onRetry,
    this.enabled = true,
  });

  final ToolsetModelRowPhase phase;

  /// The provider's name, in the footer.
  final String provider;

  /// The current model's display name.
  final String? value;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;

  /// False while a model is being written.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (phase) {
      ToolsetModelRowPhase.loading => GroupedSection(
        header: l10n.toolsModelTitle,
        children: [ToolsLoadingRow(l10n.toolsSetupLoading)],
      ),
      ToolsetModelRowPhase.failed => GroupedSection(
        header: l10n.toolsModelTitle,
        children: [
          ToolsFailureRow(
            text: l10n.toolsReadFailed,
            onRetry: onRetry ?? () {},
          ),
        ],
      ),
      ToolsetModelRowPhase.ready => GroupedSection(
        footer: l10n.toolsModelFooter(provider),
        children: [
          GroupedRow(
            key: const Key('tools-model-row'),
            title: l10n.toolsModelTitle,
            value: value,
            onTap: enabled ? onOpen : null,
            enabled: enabled,
          ),
        ],
      ),
    };
  }
}
