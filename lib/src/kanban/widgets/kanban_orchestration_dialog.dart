import 'package:flutter/material.dart';

import '../../widgets/grouped_dialog.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../kanban_errors.dart';
import '../kanban_models.dart';
import '../kanban_repository.dart';

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

  Widget _profilePicker(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    final names = {..._profiles, if (value.isNotEmpty) value}.toList();
    return GroupedMenuRow<String>(
      title: label,
      selected: value,
      options: ['', ...names],
      labelOf: (name) =>
          name.isEmpty ? 'Active profile (${_settings!.activeProfile})' : name,
      onSelected: (name) => setState(() => onChanged(name)),
    );
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
        if (settings == null)
          SizedBox(
            height: 80,
            child: Center(
              child: _failed
                  ? const Text('Could not load the settings')
                  : const CircularProgressIndicator.adaptive(),
            ),
          )
        else ...[
          GroupedSection(
            children: [
              GroupedSwitchRow(
                title: 'Auto-decompose triage tasks',
                caption: 'Off: decompose by hand',
                value: _autoDecompose,
                onTap: () => setState(() => _autoDecompose = !_autoDecompose),
                onChanged: (value) => setState(() => _autoDecompose = value),
              ),
              GroupedSwitchRow(
                title: 'Promote children when ready',
                value: _autoPromote,
                onTap: () => setState(() => _autoPromote = !_autoPromote),
                onChanged: (value) => setState(() => _autoPromote = value),
              ),
            ],
          ),
          GroupedSection(
            children: [
              _profilePicker(
                'Orchestrator profile',
                _orchestrator,
                (value) => _orchestrator = value,
              ),
              _profilePicker(
                'Default assignee',
                _defaultAssignee,
                (value) => _defaultAssignee = value,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
