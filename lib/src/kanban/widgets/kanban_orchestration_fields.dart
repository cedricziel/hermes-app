import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

class KanbanOrchestrationFields extends StatelessWidget {
  const KanbanOrchestrationFields({
    super.key,
    required this.autoDecompose,
    required this.autoPromote,
    required this.orchestrator,
    required this.defaultAssignee,
    required this.activeProfile,
    required this.profiles,
    required this.onDecomposeChanged,
    required this.onPromoteChanged,
    required this.onOrchestratorChanged,
    required this.onAssigneeChanged,
    this.loading = false,
    this.error,
  });

  final bool autoDecompose, autoPromote, loading;
  final String orchestrator, defaultAssignee, activeProfile;
  final List<String> profiles;
  final ValueChanged<bool> onDecomposeChanged, onPromoteChanged;
  final ValueChanged<String> onOrchestratorChanged, onAssigneeChanged;
  final String? error;

  Widget _profilePicker(
    AppLocalizations l10n,
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) => GroupedMenuRow<String>(
    title: label,
    selected: value,
    options: [
      '',
      ...{...profiles, if (value.isNotEmpty) value},
    ],
    labelOf: (name) => name.isEmpty
        ? l10n.kanbanOrchestrationActiveProfile(activeProfile)
        : name,
    onSelected: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (loading || error != null) {
      return SizedBox(
        height: 80,
        child: Center(
          child: error != null
              ? Text(error!)
              : const CircularProgressIndicator.adaptive(),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          children: [
            GroupedSwitchRow(
              title: l10n.kanbanOrchestrationAutoDecompose,
              caption: l10n.kanbanOrchestrationAutoDecomposeCaption,
              value: autoDecompose,
              onTap: () => onDecomposeChanged(!autoDecompose),
              onChanged: onDecomposeChanged,
            ),
            GroupedSwitchRow(
              title: l10n.kanbanOrchestrationAutoPromote,
              value: autoPromote,
              onTap: () => onPromoteChanged(!autoPromote),
              onChanged: onPromoteChanged,
            ),
          ],
        ),
        GroupedSection(
          children: [
            _profilePicker(
              l10n,
              l10n.kanbanOrchestrationOrchestrator,
              orchestrator,
              onOrchestratorChanged,
            ),
            _profilePicker(
              l10n,
              l10n.kanbanOrchestrationDefaultAssignee,
              defaultAssignee,
              onAssigneeChanged,
            ),
          ],
        ),
      ],
    );
  }
}
