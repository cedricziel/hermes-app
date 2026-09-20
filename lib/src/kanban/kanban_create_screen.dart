import 'package:flutter/material.dart';

import 'kanban_errors.dart';
import 'kanban_repository.dart';

/// The quick-create form. Pops `true` once the task exists.
class KanbanCreateScreen extends StatefulWidget {
  const KanbanCreateScreen({
    super.key,
    required this.repository,
    this.board,
    this.tenant,
  });

  final KanbanRepository repository;
  final String? board;
  final String? tenant;

  @override
  State<KanbanCreateScreen> createState() => _KanbanCreateScreenState();
}

class _KanbanCreateScreenState extends State<KanbanCreateScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<String> _assignees = const [];
  String? _assignee;
  int _priority = 0;
  bool _triage = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.repository
        .loadAssignees(board: widget.board)
        .then((names) {
          if (mounted) setState(() => _assignees = names);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    String? warning;
    final ok = await runKanbanAction(context, () async {
      warning = await widget.repository.createTask(
        title: title,
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        assignee: _assignee,
        tenant: widget.tenant,
        priority: _priority,
        triage: _triage,
        board: widget.board,
      );
    });
    if (!mounted) return;
    if (ok) {
      if (warning != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(warning!)));
      }
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New task'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _create,
            child: const Text('Create'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _assignee,
                decoration: const InputDecoration(labelText: 'Assignee'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Auto (triage picks)'),
                  ),
                  for (final a in _assignees)
                    DropdownMenuItem(value: a, child: Text(a)),
                ],
                onChanged: (v) => setState(() => _assignee = v),
              ),
              const SizedBox(height: 16),
              Text('Priority', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in [0, 1, 2, 3])
                    ChoiceChip(
                      label: Text(p == 0 ? 'Normal' : 'P$p'),
                      selected: _priority == p,
                      onSelected: (_) => setState(() => _priority = p),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Start as', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Triage'),
                    selected: _triage,
                    onSelected: (_) => setState(() => _triage = true),
                  ),
                  ChoiceChip(
                    label: const Text('Todo'),
                    selected: !_triage,
                    onSelected: (_) => setState(() => _triage = false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
