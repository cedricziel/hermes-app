import 'package:flutter/material.dart';

import '../models/model_provider_option.dart';
import '../models/widgets/model_picker.dart';
import '../theme/app_icons.dart';
import '../widgets/grouped_form.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'kanban_errors.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';

/// The quick-create form in grouped sections, with Create in the bar. Pops
/// `true` once the task exists.
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
  final _modelName = TextEditingController();
  List<String> _assignees = const [];
  ModelOptions? _modelOptions;
  ModelChoice? _model;
  String? _assignee;
  int _priority = 0;
  bool _triage = true;
  bool _saving = false;
  bool _estimating = false;
  KanbanEstimate? _estimate;

  @override
  void initState() {
    super.initState();
    widget.repository
        .loadAssignees(board: widget.board)
        .then((names) {
          if (mounted) setState(() => _assignees = names);
        })
        .catchError((_) {});
    widget.repository.loadModelOptions().then((options) {
      if (mounted) setState(() => _modelOptions = options);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _modelName.dispose();
    super.dispose();
  }

  Future<void> _estimateDraft() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _estimating = true);
    KanbanEstimate? estimate;
    await runKanbanAction(context, () async {
      estimate = await widget.repository.estimateText(
        title,
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
      );
    });
    if (mounted) {
      setState(() {
        _estimating = false;
        if (estimate != null) _estimate = estimate;
      });
    }
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final modelName = _modelName.text.trim();
    String? warning;
    final ok = await runKanbanAction(context, () async {
      warning = await widget.repository.createTask(
        title: title,
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        assignee: _assignee,
        tenant: widget.tenant,
        priority: _priority,
        triage: _triage,
        model: _model,
        modelName: modelName.isEmpty ? null : modelName,
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

  /// The model as a value row that opens the picker, or a free-text model
  /// name when the plugin lists no models; nothing while the list loads.
  Widget? _modelRow(BuildContext context) {
    final options = _modelOptions;
    if (options == null) return null;
    if (options.providers.isEmpty) {
      return GroupedTextFieldRow(
        label: 'Model',
        controller: _modelName,
        autocorrect: false,
      );
    }
    final model = _model;
    final effort = model?.effort;
    return GroupedValueRow(
      key: const Key('kanban-create-model'),
      title: 'Model',
      value: model == null
          ? 'Profile default'
          : [
              model.modelId,
              if (effort != null) effortLabel(effort),
            ].join(' · '),
      onTap: () => showModelPicker(
        context,
        options: options,
        selected: model,
        onChanged: (choice) => setState(() => _model = choice),
        onUseDefault: () => setState(() => _model = null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = _modelRow(context);
    final estimate = _estimate;
    final canEstimate = !_estimating && _title.text.trim().isNotEmpty;
    return SettingsScaffold(
      title: 'New task',
      subtitle: widget.board,
      cancel: true,
      formAction: SettingsFormAction(
        label: 'Create',
        busy: _saving,
        onPressed: _create,
      ),
      body: GroupedListView(
        children: [
          GroupedSection(
            children: [
              GroupedTextFieldRow(
                label: 'Title',
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _estimate = null),
              ),
              GroupedTextFieldRow(
                label: 'Description',
                controller: _body,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _estimate = null),
              ),
            ],
          ),
          GroupedSection(
            children: [
              // Greyed out like a disabled button until there is a title.
              Opacity(
                opacity: canEstimate || _estimating ? 1 : 0.45,
                child: GroupedRow(
                  key: const Key('kanban-create-estimate'),
                  leading: const AppIcon(AppIcons.speed),
                  title: 'Estimate the work',
                  // When there is no estimate it says why.
                  subtitle: estimate?.summary,
                  subtitleMaxLines: null,
                  trailing: _estimating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                  chevron: false,
                  enabled: canEstimate,
                  onTap: _estimateDraft,
                ),
              ),
            ],
          ),
          GroupedSection(
            header: 'Assignment',
            footer: model is GroupedTextFieldRow
                ? 'Leave the model empty for the profile default.'
                : null,
            children: [
              GroupedMenuRow<String>(
                title: 'Assignee',
                options: ['', ..._assignees],
                labelOf: (a) => a.isEmpty ? 'Auto (triage picks)' : a,
                selected: _assignee ?? '',
                onSelected: (a) =>
                    setState(() => _assignee = a.isEmpty ? null : a),
              ),
              ?model,
            ],
          ),
          GroupedSection(
            header: 'Priority',
            children: [
              GroupedSegmentedRow<int>(
                value: _priority,
                segments: const {0: 'Normal', 1: 'P1', 2: 'P2', 3: 'P3'},
                onChanged: (p) => setState(() => _priority = p),
              ),
            ],
          ),
          GroupedSection(
            header: 'Start as',
            children: [
              GroupedSegmentedRow<bool>(
                value: _triage,
                segments: const {true: 'Triage', false: 'Todo'},
                onChanged: (triage) => setState(() => _triage = triage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
