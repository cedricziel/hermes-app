import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'job_draft.dart';
import 'job_form_controller.dart';
import 'schedule_picker.dart';

/// Asks whether to throw away what was entered. True to discard.
Future<bool> confirmDiscard(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What you entered will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ??
    false;

/// The form for a custom task and for changing one. Pops with the saved job.
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({
    super.key,
    required this.controller,
    this.profileNames = const [],
  });

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
  late final TextEditingController _model;
  late final TextEditingController _provider;
  late final TextEditingController _script;
  late final TextEditingController _contextFrom;
  late final TextEditingController _workdir;

  JobFormController get _form => widget.controller;
  JobDraft get _draft => _form.draft;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _draft.name);
    _prompt = TextEditingController(text: _draft.prompt);
    _skills = TextEditingController(text: _draft.skills.join(', '));
    _model = TextEditingController(text: _draft.model);
    _provider = TextEditingController(text: _draft.provider);
    _script = TextEditingController(text: _draft.script);
    _contextFrom = TextEditingController(text: _draft.contextFrom.join(', '));
    _workdir = TextEditingController(text: _draft.workdir);
    _form.loadTargets();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _prompt,
      _skills,
      _model,
      _provider,
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
        final theme = Theme.of(context);
        final target = _form.selectedTarget;
        return PopScope(
          canPop: !_form.isDirty,
          onPopInvokedWithResult: (didPop, _) => _close(didPop),
          child: Scaffold(
            appBar: AppBar(
              leading: const CloseButton(),
              title: Text(_form.isEditing ? 'Edit task' : 'New task'),
              actions: [
                TextButton(
                  onPressed: _form.saving ? null : _save,
                  child: const Text('Save'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const Key('job-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) {
                    _draft.name = v;
                    _form.changed();
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('job-prompt'),
                  controller: _prompt,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    hintText: 'What should Hermes do each time?',
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) {
                    _draft.prompt = v;
                    _form.changed();
                  },
                ),
                const SizedBox(height: 20),
                Text('When', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SchedulePicker(
                  spec: _draft.spec,
                  now: _form.now,
                  onChanged: (spec) {
                    _draft.spec = spec;
                    _form.changed(when: true);
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: const Key('job-deliver'),
                  initialValue: _draft.deliver,
                  decoration: const InputDecoration(
                    labelText: 'Deliver results to',
                  ),
                  items: [
                    for (final t in _form.targets)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    _draft.deliver = id;
                    _form.changed();
                  },
                ),
                if (target != null && !target.homeTargetSet)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      spacing: 6,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: context.hermesColors.warning,
                        ),
                        const Expanded(
                          child: Text(
                            'No home channel is set on the server for this platform.',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_form.isEditing && widget.profileNames.length > 1) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('job-profile'),
                    initialValue: widget.profileNames.contains(_draft.profile)
                        ? _draft.profile
                        : null,
                    decoration: const InputDecoration(labelText: 'Profile'),
                    items: [
                      for (final p in widget.profileNames)
                        DropdownMenuItem(value: p, child: Text(p)),
                    ],
                    onChanged: (p) {
                      _draft.profile = p;
                      _form.changed();
                    },
                  ),
                ],
                if (!_form.isEditing)
                  SwitchListTile(
                    key: const Key('job-paused'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start paused'),
                    value: _draft.paused,
                    onChanged: (v) {
                      _draft.paused = v;
                      _form.changed();
                    },
                  ),
                const SizedBox(height: 8),
                ExpansionTile(
                  key: const Key('job-advanced'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced'),
                  initiallyExpanded: _hasAdvanced,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    _field(
                      const Key('job-skills'),
                      _skills,
                      'Skills',
                      helper: 'Names, separated by commas',
                      onChanged: (v) => _draft.skills = JobDraft.parseNames(v),
                    ),
                    _field(
                      const Key('job-model'),
                      _model,
                      'Model',
                      onChanged: (v) => _draft.model = v,
                    ),
                    _field(
                      const Key('job-provider'),
                      _provider,
                      'Provider',
                      onChanged: (v) => _draft.provider = v,
                    ),
                    _field(
                      const Key('job-script'),
                      _script,
                      'Pre-run script',
                      helper: 'A file in the profile’s scripts folder; its output is added to the prompt',
                      onChanged: (v) => _draft.script = v,
                    ),
                    _field(
                      const Key('job-context'),
                      _contextFrom,
                      'Take context from',
                      helper: 'Ids of other tasks, separated by commas',
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
                ),
                if (_form.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _form.error!,
                    key: const Key('job-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _form.saving ? null : _save,
                  child: _form.saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save task'),
                ),
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
    String? helper,
    required ValueChanged<String> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      key: key,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
      ),
      onChanged: (v) {
        onChanged(v);
        _form.changed();
      },
    ),
  );
}
