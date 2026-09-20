import 'package:flutter/material.dart';

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
    } catch (_) {
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
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text('Active profile (${_settings!.activeProfile})'),
        ),
        for (final n in names) DropdownMenuItem(value: n, child: Text(n)),
      ],
      onChanged: (v) => setState(() => onChanged(v ?? '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return AlertDialog(
      title: const Text('Orchestration'),
      content: settings == null
          ? SizedBox(
              height: 80,
              child: Center(
                child: _failed
                    ? const Text('Could not load the settings')
                    : const CircularProgressIndicator(),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-decompose triage tasks'),
                      subtitle: const Text('Off: decompose by hand'),
                      value: _autoDecompose,
                      onChanged: (v) => setState(() => _autoDecompose = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Promote children when ready'),
                      value: _autoPromote,
                      onChanged: (v) => setState(() => _autoPromote = v),
                    ),
                    _profilePicker(
                      'Orchestrator profile',
                      _orchestrator,
                      (v) => _orchestrator = v,
                    ),
                    const SizedBox(height: 8),
                    _profilePicker(
                      'Default assignee',
                      _defaultAssignee,
                      (v) => _defaultAssignee = v,
                    ),
                  ],
                ),
              ),
            ),
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
    );
  }
}
