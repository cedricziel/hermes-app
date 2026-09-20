import 'package:flutter/material.dart';

import 'hermes_cron_repository.dart';
import 'job_draft.dart';
import 'job_form_controller.dart';
import 'job_form_screen.dart';
import 'schedule_models.dart';

/// "New task": a card for a custom task and one for each blueprint the
/// server offers. Pops with the job that was created.
class BlueprintGalleryScreen extends StatefulWidget {
  const BlueprintGalleryScreen({
    super.key,
    required this.repository,
    this.profile,
    this.profileNames = const [],
  });

  final HermesCronRepository repository;

  /// The profile new jobs go to unless the form says otherwise.
  final String? profile;
  final List<String> profileNames;

  @override
  State<BlueprintGalleryScreen> createState() => _BlueprintGalleryScreenState();
}

class _BlueprintGalleryScreenState extends State<BlueprintGalleryScreen> {
  List<Blueprint>? _blueprints;
  bool _failed = false;
  String _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final blueprints = await widget.repository.blueprints();
      if (mounted) setState(() => _blueprints = blueprints);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(Widget screen) async {
    final job = await Navigator.of(context)
        .push<CronJob>(MaterialPageRoute(builder: (_) => screen));
    if (job != null && mounted) Navigator.of(context).pop(job);
  }

  void _custom() => _open(
    JobFormScreen(
      controller: JobFormController(
        repository: widget.repository,
        profile: widget.profile,
      ),
      profileNames: widget.profileNames,
    ),
  );

  void _blueprint(Blueprint blueprint) => _open(
    BlueprintFormScreen(
      controller: BlueprintFormController(
        repository: widget.repository,
        blueprint: blueprint,
        profile: widget.profile,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blueprints = _blueprints ?? const <Blueprint>[];
    final categories = {
      for (final b in blueprints)
        if (b.category.isNotEmpty) b.category,
    }.toList();
    final shown = [
      for (final b in blueprints)
        if (b.matches(_query) && (_category == null || b.category == _category))
          b,
    ];
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('New scheduled task'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: ListTile(
              key: const Key('custom-task'),
              leading: const Icon(Icons.add),
              title: const Text('Custom task'),
              subtitle: const Text('Start from scratch'),
              onTap: _custom,
            ),
          ),
          const SizedBox(height: 16),
          if (_failed)
            Row(
              children: [
                const Expanded(
                  child: Text('The templates could not be loaded.'),
                ),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            )
          else if (_blueprints == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            TextField(
              key: const Key('blueprint-search'),
              decoration: const InputDecoration(
                hintText: 'Search templates',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c[0].toUpperCase() + c.substring(1)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No templates match')),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final b in shown)
                    SizedBox(
                      width: 260,
                      child: _BlueprintCard(
                        blueprint: b,
                        onTap: () => _blueprint(b),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _BlueprintCard extends StatelessWidget {
  const _BlueprintCard({required this.blueprint, required this.onTap});

  final Blueprint blueprint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(blueprint.title, style: theme.textTheme.titleSmall),
              if (blueprint.description.isNotEmpty)
                Text(
                  blueprint.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              if (blueprint.scheduleHuman.isNotEmpty)
                Text(
                  blueprint.scheduleHuman,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A blueprint's form, built from the slots the server describes. Pops with
/// the job that was created.
class BlueprintFormScreen extends StatefulWidget {
  const BlueprintFormScreen({super.key, required this.controller});

  final BlueprintFormController controller;

  @override
  State<BlueprintFormScreen> createState() => _BlueprintFormScreenState();
}

class _BlueprintFormScreenState extends State<BlueprintFormScreen> {
  BlueprintFormController get _form => widget.controller;

  Future<void> _save() async {
    final job = await _form.save();
    if (job != null && mounted) Navigator.of(context).pop(job);
  }

  Future<void> _pickTime(BlueprintField field) async {
    final current = RegExp(r'^(\d{1,2}):(\d{2})$')
        .firstMatch('${_form.values[field.name] ?? ''}');
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(
              hour: int.parse(current.group(1)!),
              minute: int.parse(current.group(2)!),
            ),
    );
    if (picked == null) return;
    _form.set(
      field.name,
      '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  Widget _input(BlueprintField field) {
    final error = _form.fieldErrors[field.name];
    final value = '${_form.values[field.name] ?? ''}';
    final Widget input;
    if (field.type == 'time') {
      input = Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: Key('slot-${field.name}'),
          onPressed: () => _pickTime(field),
          icon: const Icon(Icons.access_time, size: 18),
          label: Text(value.isEmpty ? 'Choose a time' : value),
        ),
      );
    } else if (field.options.isNotEmpty) {
      input = Wrap(
        key: Key('slot-${field.name}'),
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in field.options)
            ChoiceChip(
              label: Text(option),
              selected: value == option,
              onSelected: (_) => _form.set(field.name, option),
            ),
        ],
      );
    } else {
      input = TextFormField(
        key: Key('slot-${field.name}'),
        initialValue: value,
        decoration: const InputDecoration(),
        minLines: 1,
        maxLines: 3,
        onChanged: (v) => _form.set(field.name, v),
      );
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            field.optional ? '${field.label} (optional)' : field.label,
            style: theme.textTheme.titleSmall,
          ),
          input,
          if (field.help.isNotEmpty)
            Text(
              field.help,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (error != null)
            Text(
              error,
              key: Key('slot-error-${field.name}'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) {
        final blueprint = _form.blueprint;
        return Scaffold(
          appBar: AppBar(title: Text(blueprint.title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (blueprint.description.isNotEmpty) ...[
                Text(blueprint.description),
                const SizedBox(height: 20),
              ],
              for (final field in blueprint.fields) _input(field),
              if (_form.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _form.error!,
                    key: const Key('blueprint-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _form.saving ? null : _save,
                child: _form.saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create task'),
              ),
            ],
          ),
        );
      },
    );
  }
}
