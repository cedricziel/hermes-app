import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../api/hermes_repositories.dart';
import '../models/hermes_models_repository.dart';
import '../theme/app_icons.dart';
import '../widgets/grouped_form.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'job_draft.dart';
import 'job_form_controller.dart';
import 'schedule_picker.dart';
import 'widgets/job_model_field.dart';

/// Asks whether to throw away what was entered. True to discard.
Future<bool> confirmDiscard(BuildContext context) => showConfirmDialog(
  context,
  title: 'Discard changes?',
  message: 'What you entered will be lost.',
  confirmLabel: 'Discard',
  cancelLabel: 'Keep editing',
  destructive: true,
  filled: false,
);

/// The form for a custom task and for changing one. Pops with the saved job.
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({
    super.key,
    required this.controller,
    this.profileNames = const [],
    this.models,
  });

  /// The models to offer; read from [HermesRepositories] when null.
  final HermesModelsRepository? models;

  /// Owned by the screen, which disposes it.
  final JobFormController controller;

  /// The profiles a new job can be created in. One or none hides the choice.
  final List<String> profileNames;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _prompt;
  late final TextEditingController _skills;
  late final TextEditingController _script;
  late final TextEditingController _contextFrom;
  late final TextEditingController _workdir;
  late bool _advancedOpen = _hasAdvanced;

  JobFormController get _form => widget.controller;
  JobDraft get _draft => _form.draft;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _draft.name);
    _prompt = TextEditingController(text: _draft.prompt);
    _skills = TextEditingController(text: _draft.skills.join(', '));
    _script = TextEditingController(text: _draft.script);
    _contextFrom = TextEditingController(text: _draft.contextFrom.join(', '));
    _workdir = TextEditingController(text: _draft.workdir);
    _form.loadTargets();
    _loadModels();
  }

  void _loadModels() {
    final models = widget.models ?? HermesRepositories.maybeOf(context)?.models;
    if (models != null) _form.loadModels(models);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _prompt,
      _skills,
      _script,
      _contextFrom,
      _workdir,
    ]) {
      c.dispose();
    }
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final job = await _form.save();
    if (job != null && mounted) Navigator.of(context).pop(job);
  }

  Future<void> _close(bool didPop) async {
    if (didPop) return;
    if (await confirmDiscard(context) && mounted) {
      Navigator.of(context).pop();
    }
  }

  bool get _hasAdvanced =>
      _draft.skills.isNotEmpty ||
      _draft.model.isNotEmpty ||
      _draft.provider.isNotEmpty ||
      _draft.script.isNotEmpty ||
      _draft.contextFrom.isNotEmpty ||
      _draft.workdir.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) {
        final target = _form.selectedTarget;
        final targets = _form.targets;
        final profile = _draft.profile;
        return PopScope(
          canPop: !_form.isDirty,
          onPopInvokedWithResult: (didPop, _) => _close(didPop),
          child: SettingsScaffold(
            title: _form.isEditing ? 'Edit task' : 'New task',
            subtitle: profile,
            previousTitle: null,
            cancel: true,
            formAction: SettingsFormAction(
              label: 'Save',
              busy: _form.saving,
              onPressed: _save,
            ),
            body: GroupedListView(
              children: [
                GroupedSection(
                  children: [
                    GroupedTextFieldRow(
                      key: const Key('job-name'),
                      label: 'Name',
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (v) {
                        _draft.name = v;
                        _form.changed();
                      },
                    ),
                    GroupedTextFieldRow(
                      key: const Key('job-prompt'),
                      label: 'Task',
                      hint: 'What should Hermes do each time?',
                      controller: _prompt,
                      minLines: 3,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (v) {
                        _draft.prompt = v;
                        _form.changed();
                      },
                    ),
                  ],
                ),
                SchedulePicker(
                  spec: _draft.spec,
                  now: _form.now,
                  onChanged: (spec) {
                    _draft.spec = spec;
                    _form.changed(when: true);
                  },
                ),
                GroupedSection(
                  header: 'Delivery',
                  children: [
                    GroupedMenuRow<String>(
                      key: const Key('job-deliver'),
                      title: 'Deliver results to',
                      options: [for (final t in targets) t.id],
                      labelOf: (id) => target?.id == id
                          ? target!.name
                          : targets
                                    .where((t) => t.id == id)
                                    .firstOrNull
                                    ?.name ??
                                id,
                      selected: _draft.deliver,
                      warning: target != null && !target.homeTargetSet
                          ? 'No home channel is set on the server for this '
                                'platform.'
                          : null,
                      onSelected: (id) {
                        _draft.deliver = id;
                        _form.changed();
                      },
                    ),
                    if (!_form.isEditing && widget.profileNames.length > 1)
                      GroupedMenuRow<String>(
                        key: const Key('job-profile'),
                        title: 'Profile',
                        options: widget.profileNames,
                        labelOf: (p) => p,
                        selected: widget.profileNames.contains(profile)
                            ? profile
                            : null,
                        onSelected: (p) {
                          _draft.profile = p;
                          _form.changed();
                          _form.loadTargets();
                          _loadModels();
                        },
                      ),
                    if (!_form.isEditing)
                      GroupedSwitchRow(
                        key: const Key('job-paused'),
                        title: 'Start paused',
                        value: _draft.paused,
                        onChanged: (v) {
                          _draft.paused = v;
                          _form.changed();
                        },
                      ),
                  ],
                ),
                GroupedSection(
                  footer: _advancedOpen
                      ? 'Skills and task ids are separated by commas. The '
                            'pre-run script is a file in the profile’s scripts '
                            'folder; its output is added to the prompt.'
                      : null,
                  children: [
                    _AdvancedRow(
                      key: const Key('job-advanced'),
                      open: _advancedOpen,
                      onTap: () =>
                          setState(() => _advancedOpen = !_advancedOpen),
                    ),
                    if (_advancedOpen) ...[
                      _field(
                        const Key('job-skills'),
                        _skills,
                        'Skills',
                        onChanged: (v) =>
                            _draft.skills = JobDraft.parseNames(v),
                      ),
                      JobModelField(
                        options: _form.modelOptions,
                        model: _draft.model,
                        provider: _draft.provider,
                        onChanged: (model, provider) {
                          _draft
                            ..model = model
                            ..provider = provider;
                          _form.changed();
                        },
                      ),
                      _field(
                        const Key('job-script'),
                        _script,
                        'Pre-run script',
                        onChanged: (v) => _draft.script = v,
                      ),
                      _field(
                        const Key('job-context'),
                        _contextFrom,
                        'Take context from',
                        hint: 'Task ids',
                        onChanged: (v) =>
                            _draft.contextFrom = JobDraft.parseNames(v),
                      ),
                      _field(
                        const Key('job-workdir'),
                        _workdir,
                        'Working directory',
                        onChanged: (v) => _draft.workdir = v,
                      ),
                    ],
                  ],
                ),
                if (_form.error case final error?)
                  GroupedFormError(error, key: const Key('job-error')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _field(
    Key key,
    TextEditingController controller,
    String label, {
    String? hint,
    required ValueChanged<String> onChanged,
  }) => GroupedTextFieldRow(
    key: key,
    label: label,
    hint: hint,
    controller: controller,
    autocorrect: false,
    onChanged: (v) {
      onChanged(v);
      _form.changed();
    },
  );
}

/// The row that shows or hides the advanced fields under it.
class _AdvancedRow extends StatelessWidget {
  const _AdvancedRow({super.key, required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        child: GroupedRow(
          title: 'Advanced',
          trailing: AnimatedRotation(
            turns: open ? 0.25 : 0,
            duration: const Duration(milliseconds: 150),
            child: AppIcon(
              AppIcons.chevronRight,
              size: 18,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
      ),
    ),
  );
}
