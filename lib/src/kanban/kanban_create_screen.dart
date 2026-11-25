import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../models/model_provider_option.dart';
import '../models/widgets/model_picker.dart';
import '../theme/app_icons.dart';
import '../widgets/grouped_form.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'kanban_errors.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';
import '../widgets/route_dismissal.dart';

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
        .catchError((Object _) {}, test: (e) => e is Exception);
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
      dismissRoute(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  /// The model as a value row that opens the picker, or a free-text model
  /// name when the plugin lists no models; nothing while the list loads.
  Widget? _modelRow(BuildContext context) {
    final options = _modelOptions;
    if (options == null) return null;
    final l10n = context.l10n;
    if (options.providers.isEmpty) {
      return GroupedTextFieldRow(
        label: l10n.kanbanTaskModel,
        controller: _modelName,
        autocorrect: false,
      );
    }
    final model = _model;
    final effort = model?.effort;
    return GroupedValueRow(
      key: const Key('kanban-create-model'),
      title: l10n.kanbanTaskModel,
      value: model == null
          ? l10n.kanbanBulkEffortDefault
          : [
              model.modelId,
              if (effort != null) effortLabel(l10n, effort),
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
    final l10n = context.l10n;
    final model = _modelRow(context);
    final estimate = _estimate;
    final canEstimate = !_estimating && _title.text.trim().isNotEmpty;
    return SettingsScaffold(
      title: l10n.kanbanNewTaskAction,
      subtitle: widget.board,
      cancel: true,
      formAction: SettingsFormAction(
        label: l10n.kanbanBoardsCreate,
        busy: _saving,
        onPressed: _create,
      ),
      body: GroupedListView(
        children: [
          GroupedSection(
            children: [
              GroupedTextFieldRow(
                label: l10n.kanbanEditTaskTitleLabel,
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _estimate = null),
              ),
              GroupedTextFieldRow(
                label: l10n.kanbanEditTaskDescriptionLabel,
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
                  title: l10n.kanbanCreateEstimate,
                  // When there is no estimate it says why.
                  subtitle: estimate == null
                      ? null
                      : kanbanEstimateSummary(l10n, estimate),
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
            header: l10n.kanbanCreateAssignment,
            footer: model is GroupedTextFieldRow
                ? l10n.kanbanCreateModelFooter
                : null,
            children: [
              GroupedMenuRow<String>(
                title: l10n.kanbanTaskAssignee,
                options: ['', ..._assignees],
                labelOf: (a) => a.isEmpty ? l10n.kanbanCreateAssigneeAuto : a,
                selected: _assignee ?? '',
                onSelected: (a) =>
                    setState(() => _assignee = a.isEmpty ? null : a),
              ),
              ?model,
            ],
          ),
          GroupedSection(
            header: l10n.kanbanBulkPriorityTitle,
            children: [
              GroupedSegmentedRow<int>(
                value: _priority,
                segments: {
                  0: l10n.kanbanBulkPriorityNormal,
                  for (final p in [1, 2, 3]) p: l10n.kanbanTaskPriorityLevel(p),
                },
                onChanged: (p) => setState(() => _priority = p),
              ),
            ],
          ),
          GroupedSection(
            header: l10n.kanbanCreateStartAs,
            children: [
              GroupedSegmentedRow<bool>(
                value: _triage,
                segments: {
                  true: kanbanStatusLabel(l10n, 'triage'),
                  false: kanbanStatusLabel(l10n, 'todo'),
                },
                onChanged: (triage) => setState(() => _triage = triage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
