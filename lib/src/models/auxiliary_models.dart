import 'model_provider_option.dart';

/// What the app calls the side jobs of Hermes' `_AUX_TASK_SLOTS`.
const _taskLabels = {
  'vision': 'Vision',
  'compression': 'Context compression',
  'skills_hub': 'Skills Hub search',
  'approval': 'Approval checks',
  'mcp': 'MCP tool routing',
  'title_generation': 'Chat titles',
  'review': 'Review',
  'triage_specifier': 'Kanban triage',
  'kanban_decomposer': 'Kanban task breakdown',
  'profile_describer': 'Profile descriptions',
  'curator': 'Skill curator',
};

/// One side job and the model it runs on; a null [choice] is Hermes' `auto`,
/// which uses the main model.
class AuxiliarySlot {
  const AuxiliarySlot({required this.task, this.choice});

  final String task;
  final ModelChoice? choice;

  String get label => _taskLabels[task] ?? task;
}

/// The helper model slots of a profile and its main model, from
/// `GET /api/model/auxiliary`.
class AuxiliaryModels {
  const AuxiliaryModels({this.slots = const [], this.main});

  /// The route has no response schema. Rows without a task are skipped.
  factory AuxiliaryModels.fromJson(Object? body) {
    final json = body is Map ? body : const {};
    final rows = json['tasks'] is List ? json['tasks'] as List : const [];
    final main = json['main'] is Map ? json['main'] as Map : const {};
    return AuxiliaryModels(
      slots: [
        for (final row in rows.whereType<Map<Object?, Object?>>())
          if (row['task'] case final String task when task.isNotEmpty)
            AuxiliarySlot(task: task, choice: _choice(row)),
      ],
      main: _choice(main),
    );
  }

  final List<AuxiliarySlot> slots;
  final ModelChoice? main;

  AuxiliaryModels withSlot(AuxiliarySlot slot) => AuxiliaryModels(
    slots: [for (final s in slots) s.task == slot.task ? slot : s],
    main: main,
  );

  static ModelChoice? _choice(Map<Object?, Object?> row) {
    final provider = row['provider'];
    final model = row['model'];
    final effort = row['reasoning_effort'];
    if (provider is! String || provider.isEmpty || provider == 'auto') {
      return null;
    }
    return ModelChoice(
      provider,
      model is String ? model : '',
      effort: effort is String && effort.isNotEmpty ? effort : null,
    );
  }
}
