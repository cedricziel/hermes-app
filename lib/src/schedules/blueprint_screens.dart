import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_pickers.dart';

import '../theme/app_icons.dart';
import '../widgets/grouped_choice_row.dart';
import '../widgets/grouped_form.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_search_field.dart';
import 'hermes_cron_repository.dart';
import 'job_draft.dart';
import 'job_form_controller.dart';
import 'job_form_screen.dart';
import 'schedule_models.dart';

/// "New task": a custom task, then the blueprints the server offers grouped
/// by category, which the search field and its category filter narrow. Pops
/// with the job that was created.
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
      final blueprints = await widget.repository.blueprints(
        profile: widget.profile,
      );
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

  static String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final blueprints = _blueprints;
    final categories = {
      for (final b in blueprints ?? const <Blueprint>[])
        if (b.category.isNotEmpty) b.category,
    }.toList();
    final shown = <String, List<Blueprint>>{};
    for (final b in blueprints ?? const <Blueprint>[]) {
      if (b.matches(_query) && (_category == null || b.category == _category)) {
        (shown[b.category] ??= []).add(b);
      }
    }
    return SettingsScaffold(
      title: 'New scheduled task',
      subtitle: widget.profile,
      cancel: true,
      search: blueprints == null
          ? null
          : SettingsSearch(
              query: _query,
              hint: 'Search templates',
              onChanged: (v) => setState(() => _query = v),
              filters: categories.isEmpty
                  ? const []
                  : [
                      SettingsFilter(
                        label: 'All',
                        selected: _category == null,
                        onSelected: () => setState(() => _category = null),
                      ),
                      for (final c in categories)
                        SettingsFilter(
                          label: _capitalized(c),
                          selected: _category == c,
                          onSelected: () => setState(() => _category = c),
                        ),
                    ],
            ),
      body: GroupedListView(
        children: [
          GroupedSection(
            dividerIndent: GroupedMetrics.of(context).indentAfterTile,
            children: [
              GroupedRow(
                key: const Key('custom-task'),
                leading: const GroupedTile(child: AppIcon(AppIcons.add)),
                title: 'Custom task',
                subtitle: 'Start from scratch',
                onTap: _custom,
              ),
            ],
          ),
          if (_failed)
            GroupedSection(
              header: 'Templates',
              footer: 'The templates could not be loaded.',
              children: [GroupedRow(title: 'Retry', onTap: _load)],
            )
          else if (blueprints == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (shown.isEmpty)
            const GroupedFooter('No templates match')
          else
            for (final MapEntry(key: category, value: rows) in shown.entries)
              GroupedSection(
                header: category.isEmpty ? 'Templates' : _capitalized(category),
                children: [
                  for (final b in rows)
                    GroupedRow(
                      title: b.title,
                      subtitle: b.description.isEmpty ? null : b.description,
                      caption: b.scheduleHuman.isEmpty ? null : b.scheduleHuman,
                      onTap: () => _blueprint(b),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

/// A blueprint's form, built from the slots the server describes: one group
/// per slot with its help as the footer. Pops with the job that was created.
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
    if (!mounted) return;
    if (job != null) {
      Navigator.of(context).pop(job);
    } else {
      revealFormError(context);
    }
  }

  Future<void> _pickTime(BlueprintField field) async {
    final current = RegExp(r'^(\d{1,2}):(\d{2})$')
        .firstMatch('${_form.values[field.name] ?? ''}');
    final picked = await pickTime(
      context,
      initial: current == null
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

  List<Widget> _slot(BlueprintField field) {
    final error = _form.fieldErrors[field.name];
    final value = '${_form.values[field.name] ?? ''}';
    final label = field.optional ? '${field.label} (optional)' : field.label;
    final help = field.help.isEmpty ? null : field.help;
    final Widget section;
    if (field.type == 'time') {
      section = GroupedSection(
        footer: help,
        children: [
          GroupedValueRow(
            key: Key('slot-${field.name}'),
            title: label,
            value: value.isEmpty ? 'Choose a time' : value,
            onTap: () => _pickTime(field),
          ),
        ],
      );
    } else if (field.options.isNotEmpty) {
      section = RadioGroup<String>(
        key: Key('slot-${field.name}'),
        groupValue: value,
        onChanged: (option) {
          if (option != null) _form.set(field.name, option);
        },
        child: GroupedSection(
          header: label,
          footer: help,
          dividerIndent: GroupedChoiceRow.dividerIndent(context),
          children: [
            for (final option in field.options)
              GroupedChoiceRow<String>(value: option, title: option),
          ],
        ),
      );
    } else {
      section = GroupedSection(
        footer: help,
        children: [
          GroupedTextFieldRow(
            key: Key('slot-${field.name}'),
            label: label,
            initialValue: value,
            minLines: 1,
            maxLines: 3,
            onChanged: (v) => _form.set(field.name, v),
          ),
        ],
      );
    }
    return [
      section,
      if (error != null)
        GroupedFooter(error, key: Key('slot-error-${field.name}'), error: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) {
        final blueprint = _form.blueprint;
        return SettingsScaffold(
          title: blueprint.title,
          subtitle: _form.profile,
          previousTitle: null,
          formAction: SettingsFormAction(
            label: 'Create',
            busy: _form.saving,
            onPressed: _save,
          ),
          body: GroupedListView(
            children: [
              if (_form.error ??
                      (_form.fieldErrors.isEmpty
                          ? null
                          : 'Check the fields marked below.')
                  case final error?)
                GroupedFooter(
                  error,
                  key: const Key('blueprint-error'),
                  error: true,
                ),
              if (blueprint.description.isNotEmpty)
                GroupedFooter(blueprint.description),
              for (final field in blueprint.fields) ..._slot(field),
            ],
          ),
        );
      },
    );
  }
}
