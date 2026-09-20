import 'package:flutter/foundation.dart';
import 'package:hermes_api/hermes_api.dart' show CronJobCreate;

import 'schedule_models.dart';
import 'schedule_spec.dart';

/// The values of the job form. One draft starts empty for a new job, or from
/// a stored job for an edit, where [diff] then names only what changed.
class JobDraft {
  JobDraft({
    this.name = '',
    this.prompt = '',
    this.spec = const EverySpec(1, EveryUnit.hours),
    this.deliver = 'local',
    this.skills = const [],
    this.model = '',
    this.provider = '',
    this.script = '',
    this.contextFrom = const [],
    this.workdir = '',
    this.paused = false,
    this.profile,
  });

  factory JobDraft.fromJob(CronJob job) => JobDraft(
    name: job.name,
    prompt: job.prompt,
    spec: ScheduleSpec.fromJob(job),
    deliver: job.deliver ?? 'local',
    skills: job.skills,
    model: job.model ?? '',
    provider: job.provider ?? '',
    script: job.script ?? '',
    contextFrom: job.contextFrom,
    workdir: job.workdir ?? '',
    profile: job.profile,
  );

  String name;
  String prompt;
  ScheduleSpec spec;
  String deliver;
  List<String> skills;
  String model;
  String provider;
  String script;
  List<String> contextFrom;
  String workdir;
  bool paused;
  String? profile;

  /// Names separated by commas or lines, as typed in the form.
  static List<String> parseNames(String text) => [
    for (final part in text.split(RegExp(r'[\n,]')))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  /// Why the job cannot be saved yet, or null.
  String? validate(DateTime now) {
    final schedule = spec.validate(now);
    if (schedule != null) return schedule;
    if (prompt.trim().isEmpty && skills.isEmpty && script.trim().isEmpty) {
      return 'A task needs a prompt, a skill or a script';
    }
    return null;
  }

  String? _absent(String text) => text.trim().isEmpty ? null : text.trim();

  CronJobCreate toCreate() => CronJobCreate(
    name: name.trim(),
    prompt: prompt.trim(),
    schedule: spec.toSchedule(),
    deliver: deliver,
    skills: skills.isEmpty ? null : skills,
    model: _absent(model),
    provider: _absent(provider),
    script: _absent(script),
    contextFrom: contextFrom.isEmpty ? null : contextFrom,
    workdir: _absent(workdir),
    paused: paused,
  );

  /// The `updates` for `PUT /api/cron/jobs/{id}`: only what differs from
  /// [original]. A schedule goes only when [whenTouched]; a text the user
  /// emptied goes as an empty string, which clears it.
  Map<String, Object> diff(JobDraft original, {required bool whenTouched}) {
    final updates = <String, Object>{};
    void text(String key, String now, String before) {
      if (now.trim() != before.trim()) updates[key] = now.trim();
    }

    void names(String key, List<String> now, List<String> before) {
      if (!listEquals(now, before)) updates[key] = now;
    }

    text('name', name, original.name);
    text('prompt', prompt, original.prompt);
    text('model', model, original.model);
    text('provider', provider, original.provider);
    text('script', script, original.script);
    text('workdir', workdir, original.workdir);
    if (deliver != original.deliver) updates['deliver'] = deliver;
    names('skills', skills, original.skills);
    names('context_from', contextFrom, original.contextFrom);
    if (whenTouched) updates['schedule'] = spec.toSchedule();
    return updates;
  }
}

/// A blueprint's slot, as `GET /api/cron/blueprints` describes it.
class BlueprintField {
  const BlueprintField({
    required this.name,
    required this.type,
    required this.label,
    this.defaultValue,
    this.options = const [],
    this.optional = false,
    this.strict = true,
    this.help = '',
  });

  final String name;

  /// `time`, `enum`, `text` or `weekdays`; an unknown type is shown as text.
  final String type;
  final String label;
  final Object? defaultValue;
  final List<String> options;
  final bool optional;
  final bool strict;
  final String help;

  static BlueprintField? fromJson(Object? row) {
    if (row is! Map) return null;
    final name = row['name'];
    if (name is! String || name.isEmpty) return null;
    final options = row['options'];
    return BlueprintField(
      name: name,
      type: row['type'] is String ? row['type'] as String : 'text',
      label: row['label'] is String && (row['label'] as String).isNotEmpty
          ? row['label'] as String
          : name,
      defaultValue: row['default'],
      options: options is List
          ? [for (final o in options) o.toString()]
          : const [],
      optional: row['optional'] == true,
      strict: row['strict'] != false,
      help: row['help'] is String ? row['help'] as String : '',
    );
  }
}

class Blueprint {
  const Blueprint({
    required this.key,
    required this.title,
    this.description = '',
    this.category = '',
    this.tags = const [],
    this.scheduleHuman = '',
    this.fields = const [],
  });

  final String key;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String scheduleHuman;
  final List<BlueprintField> fields;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }

  /// The slot a server message is about, found by its name as a word.
  BlueprintField? fieldIn(String message) {
    for (final field in fields) {
      if (RegExp('\\b${RegExp.escape(field.name)}\\b').hasMatch(message)) {
        return field;
      }
    }
    return null;
  }

  static Blueprint? fromJson(Object? row) {
    if (row is! Map) return null;
    final key = row['key'];
    if (key is! String || key.isEmpty) return null;
    final title = row['title'];
    final fields = row['fields'];
    final tags = row['tags'];
    return Blueprint(
      key: key,
      title: title is String && title.isNotEmpty ? title : key,
      description: row['description'] is String
          ? row['description'] as String
          : '',
      category: row['category'] is String ? row['category'] as String : '',
      tags: tags is List ? [for (final t in tags) t.toString()] : const [],
      scheduleHuman: row['scheduleHuman'] is String
          ? row['scheduleHuman'] as String
          : '',
      fields: fields is List
          ? [for (final f in fields) ?BlueprintField.fromJson(f)]
          : const [],
    );
  }
}
