import 'package:flutter/material.dart';

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
    labelOf: (name) => name.isEmpty ? 'Active profile ($activeProfile)' : name,
    onSelected: onChanged,
  );

  @override
  Widget build(BuildContext context) {
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
              title: 'Auto-decompose triage tasks',
              caption: 'Off: decompose by hand',
              value: autoDecompose,
              onTap: () => onDecomposeChanged(!autoDecompose),
              onChanged: onDecomposeChanged,
            ),
            GroupedSwitchRow(
              title: 'Promote children when ready',
              value: autoPromote,
              onTap: () => onPromoteChanged(!autoPromote),
              onChanged: onPromoteChanged,
            ),
          ],
        ),
        GroupedSection(
          children: [
            _profilePicker(
              'Orchestrator profile',
              orchestrator,
              onOrchestratorChanged,
            ),
            _profilePicker(
              'Default assignee',
              defaultAssignee,
              onAssigneeChanged,
            ),
          ],
        ),
      ],
    );
  }
}
