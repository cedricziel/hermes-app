import 'package:flutter/material.dart';

import '../../widgets/grouped_dialog.dart';
import '../kanban_errors.dart';
import '../kanban_models.dart';
import '../kanban_repository.dart';
import 'kanban_orchestration_fields.dart';

/// Edits how the plugin fans out and picks up tasks (`kanban.*` in the
/// server's config).
class KanbanOrchestrationDialog extends StatefulWidget {
  const KanbanOrchestrationDialog({
    super.key,
    required this.repository,
    this.board,
  });

  final KanbanRepository repository;
  final String? board;

  @override
  State<KanbanOrchestrationDialog> createState() =>
      _KanbanOrchestrationDialogState();
}

class _KanbanOrchestrationDialogState extends State<KanbanOrchestrationDialog> {
  KanbanOrchestration? _settings;
  List<String> _profiles = const [];
  bool _failed = false;
  late bool _autoDecompose;
  late bool _autoPromote;
  late String _orchestrator;
  late String _defaultAssignee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.repository.loadOrchestration();
      final profiles = await widget.repository
          .loadAssignees(board: widget.board)
          .catchError((_) => <String>[]);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _profiles = profiles;
        _autoDecompose = settings.autoDecompose;
        _autoPromote = settings.autoPromoteChildren;
        _orchestrator = settings.orchestratorProfile;
        _defaultAssignee = settings.defaultAssignee;
      });
    } on Object catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save() async {
    final settings = _settings!;
    final ok = await runKanbanAction(
      context,
      // Only what changed, so a stale profile name in the server's config
      // is not sent back (and refused) when an unrelated switch is toggled.
      () => widget.repository.saveOrchestration(
        orchestratorProfile: _orchestrator == settings.orchestratorProfile
            ? null
            : _orchestrator,
        defaultAssignee: _defaultAssignee == settings.defaultAssignee
            ? null
            : _defaultAssignee,
        autoDecompose: _autoDecompose == settings.autoDecompose
            ? null
            : _autoDecompose,
        autoPromoteChildren: _autoPromote == settings.autoPromoteChildren
            ? null
            : _autoPromote,
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return GroupedDialog(
      title: 'Orchestration',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: settings == null ? null : _save,
          child: const Text('Save'),
        ),
      ],
      children: [
        KanbanOrchestrationFields(
          loading: settings == null && !_failed,
          error: _failed ? 'Could not load the settings' : null,
          autoDecompose: settings == null ? false : _autoDecompose,
          autoPromote: settings == null ? false : _autoPromote,
          orchestrator: settings == null ? '' : _orchestrator,
          defaultAssignee: settings == null ? '' : _defaultAssignee,
          activeProfile: settings?.activeProfile ?? '',
          profiles: _profiles,
          onDecomposeChanged: (value) => setState(() => _autoDecompose = value),
          onPromoteChanged: (value) => setState(() => _autoPromote = value),
          onOrchestratorChanged: (value) =>
              setState(() => _orchestrator = value),
          onAssigneeChanged: (value) =>
              setState(() => _defaultAssignee = value),
        ),
      ],
    );
  }
}
